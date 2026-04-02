//
//  LiveFileWritingDecoder.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

import AVFoundation
import Combine
import CoreImage
import Foundation
import VideoToolbox

/// able to be run for both iOS and macOS
public final class LiveFileWritingDecoder: NSObject {
    private static let packetHeaderSize = 12

    /// Phase 5: Lower-level callback that delivers CVImageBuffer directly.
    /// Consumers that only need the pixel buffer (e.g., Metal views) should use this.
    public var onFrameBuffer: ((CVImageBuffer, CGSize) -> Void)?

    /// Convenience callback for consumers that need a CGImage.
    /// Only used if `onFrameBuffer` is nil.
    public var onFrameImage: ((CGImage, (width: CGFloat, height: CGFloat)) -> Void)?

    public var onStatus: ((String) -> Void)?

    private var inputStream: InputStream?
    private var buffer = Data()
    private var formatDescription: CMVideoFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private var sequenceParameterSet: Data?
    private var pictureParameterSet: Data?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// PTS sentinel used for control packets (all 0xFF bytes)
    private static let controlPacketPTSSentinel: UInt64 = UInt64.max

    override public init() {

    }

    public func start(stream: InputStream) {
        stop()

        inputStream = stream
        stream.delegate = self
        stream.schedule(in: .main, forMode: .default)
        stream.open()
        onStatus?("Receiving livestream...")
    }

    public func stop() {
        invalidateDecoder()
        buffer.removeAll(keepingCapacity: false)
        sequenceParameterSet = nil
        pictureParameterSet = nil

        guard let inputStream else { return }
        inputStream.delegate = nil
        inputStream.remove(from: .main, forMode: .default)
        inputStream.close()
        self.inputStream = nil
    }

    private func readAvailableBytes(from stream: InputStream) {
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&chunk, maxLength: chunk.count)
            if bytesRead > 0 {
                buffer.append(chunk, count: bytesRead)
                processPackets()
            } else {
                break
            }
        }
    }

    private func processPackets() {
        while buffer.count >= Self.packetHeaderSize {
            let payloadLength = Int(readUInt32(from: buffer, offset: 0))
            let packetLength = Self.packetHeaderSize + payloadLength
            guard buffer.count >= packetLength else { return }

            let ptsBits = readUInt64(from: buffer, offset: 4)
            let payload = Data(buffer[Self.packetHeaderSize..<packetLength])
            buffer.removeFirst(packetLength)

            // Phase 3: Detect control packet by sentinel PTS
            if ptsBits == Self.controlPacketPTSSentinel {
                handleFormatPacket(payload)
                continue
            }

            let presentationTime = CMTime(seconds: Double(bitPattern: ptsBits), preferredTimescale: 600)
            decode(payload: payload, presentationTime: presentationTime)
        }
    }

    // MARK: - Phase 3: SPS/PPS Control Packet Handling

    /// Parses the control packet: [0xFF marker] [SPS len (2)] [SPS] [PPS len (2)] [PPS]
    private func handleFormatPacket(_ payload: Data) {
        guard payload.count >= 1, payload[payload.startIndex] == 0xFF else { return }

        var cursor = payload.index(after: payload.startIndex)

        // Read SPS
        guard payload.distance(from: cursor, to: payload.endIndex) >= 2 else { return }
        let spsLength = Int(readUInt16(from: payload, offset: payload.distance(from: payload.startIndex, to: cursor)))
        cursor = payload.index(cursor, offsetBy: 2)
        guard payload.distance(from: cursor, to: payload.endIndex) >= spsLength else { return }
        let sps = Data(payload[cursor..<payload.index(cursor, offsetBy: spsLength)])
        cursor = payload.index(cursor, offsetBy: spsLength)

        // Read PPS
        guard payload.distance(from: cursor, to: payload.endIndex) >= 2 else { return }
        let ppsLength = Int(readUInt16(from: payload, offset: payload.distance(from: payload.startIndex, to: cursor)))
        cursor = payload.index(cursor, offsetBy: 2)
        guard payload.distance(from: cursor, to: payload.endIndex) >= ppsLength else { return }
        let pps = Data(payload[cursor..<payload.index(cursor, offsetBy: ppsLength)])

        // Build format description immediately for deterministic init
        sequenceParameterSet = sps
        pictureParameterSet = pps

        if !prepareDecoderIfNeeded() {
            onStatus?("Received format info, waiting for decoder setup...")
        }
    }

    private func decode(payload: Data, presentationTime: CMTime) {
        // Fallback: also update parameter sets from inline NAL units
        updateParameterSets(from: payload)
        guard prepareDecoderIfNeeded() else { return }
        guard let formatDescription, let decompressionSession else { return }
        guard let sampleBuffer = makeSampleBuffer(payload: payload,
                                                  formatDescription: formatDescription,
                                                  presentationTime: presentationTime) else {
            return
        }

        let status = VTDecompressionSessionDecodeFrame(
            decompressionSession,
            sampleBuffer: sampleBuffer,
            flags: [._1xRealTimePlayback],
            frameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            onStatus?("Decode error: \(status)")
            invalidateDecoder()
        }
    }

    private func updateParameterSets(from payload: Data) {
        var cursor = payload.startIndex

        while payload.distance(from: cursor, to: payload.endIndex) >= 4 {
            let nalLength = Int(readUInt32(from: payload, offset: payload.distance(from: payload.startIndex, to: cursor)))
            let nalStart = payload.index(cursor, offsetBy: 4)
            let nalEnd = payload.index(nalStart, offsetBy: nalLength, limitedBy: payload.endIndex) ?? payload.endIndex
            guard nalEnd <= payload.endIndex, nalStart < nalEnd else { break }

            let nal = payload[nalStart..<nalEnd]
            guard let firstByte = nal.first else { break }
            switch firstByte & 0x1F {
            case 7:
                sequenceParameterSet = Data(nal)
            case 8:
                pictureParameterSet = Data(nal)
            default:
                break
            }

            cursor = nalEnd
        }
    }

    private func prepareDecoderIfNeeded() -> Bool {
        guard let sequenceParameterSet, let pictureParameterSet else { return false }

        if let formatDescription,
           formatDescription.matches(sps: sequenceParameterSet, pps: pictureParameterSet),
           decompressionSession != nil {
            return true
        }

        invalidateDecoder()

        guard let description = makeFormatDescription(sps: sequenceParameterSet, pps: pictureParameterSet) else {
            onStatus?("Waiting for stream format...")
            return false
        }

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: LiveFileWritingDecoder.decompressionOutputCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let destinationAttributes: CFDictionary = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true
        ] as CFDictionary

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: description,
            decoderSpecification: nil,
            imageBufferAttributes: destinationAttributes,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            onStatus?("Unable to create decoder: \(status)")
            return false
        }

        formatDescription = description
        decompressionSession = session
        return true
    }

    private func makeFormatDescription(sps: Data, pps: Data) -> CMVideoFormatDescription? {
        var formatDescription: CMFormatDescription?
        let parameterSetSizes = [sps.count, pps.count]
        let status = sps.withUnsafeBytes { spsBuffer in
            pps.withUnsafeBytes { ppsBuffer in
                let parameterSetPointers = [
                    spsBuffer.bindMemory(to: UInt8.self).baseAddress,
                    ppsBuffer.bindMemory(to: UInt8.self).baseAddress
                ]

                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: parameterSetPointers.count,
                    parameterSetPointers: parameterSetPointers.compactMap { $0 },
                    parameterSetSizes: parameterSetSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDescription
                )
            }
        }

        guard status == noErr else { return nil }
        return formatDescription
    }

    private func makeSampleBuffer(payload: Data,
                                  formatDescription: CMVideoFormatDescription,
                                  presentationTime: CMTime) -> CMSampleBuffer? {
        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: payload.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: payload.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == kCMBlockBufferNoErr, let blockBuffer else { return nil }

        let replaceStatus = payload.withUnsafeBytes { rawBuffer in
            CMBlockBufferReplaceDataBytes(
                with: rawBuffer.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: payload.count
            )
        }

        guard replaceStatus == kCMBlockBufferNoErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = [payload.count]
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: sampleSizeArray,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr else { return nil }
        return sampleBuffer
    }

    // MARK: - Phase 5: Reduced Hot-Path Work

    private func handleDecodedImageBuffer(_ imageBuffer: CVImageBuffer) {
        let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))

        // Prefer the lower-level callback: deliver CVImageBuffer directly,
        // avoiding the expensive CIImage -> CGImage conversion
        if let onFrameBuffer {
            onFrameBuffer(imageBuffer, CGSize(width: width, height: height))
            return
        }

        // Fallback: convert to CGImage only if needed by the consumer
        if let onFrameImage {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            onFrameImage(cgImage, (width: width, height: height))
        }
    }

    private func invalidateDecoder() {
        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }
        decompressionSession = nil
        formatDescription = nil
    }

    private func readUInt16(from data: Data, offset: Int) -> UInt16 {
        let start = data.index(data.startIndex, offsetBy: offset)
        let end = data.index(start, offsetBy: 2)
        return data[start..<end].reduce(UInt16.zero) { ($0 << 8) | UInt16($1) }
    }

    private func readUInt32(from data: Data, offset: Int) -> UInt32 {
        let start = data.index(data.startIndex, offsetBy: offset)
        let end = data.index(start, offsetBy: 4)
        return data[start..<end].reduce(UInt32.zero) { ($0 << 8) | UInt32($1) }
    }

    private func readUInt64(from data: Data, offset: Int) -> UInt64 {
        let start = data.index(data.startIndex, offsetBy: offset)
        let end = data.index(start, offsetBy: 8)
        return data[start..<end].reduce(UInt64.zero) { ($0 << 8) | UInt64($1) }
    }

    // Phase 5: Decompression callback no longer forces main-queue dispatch.
    // The consumer's callback decides where to dispatch.
    private static let decompressionOutputCallback: VTDecompressionOutputCallback = { refCon, _, status, _, imageBuffer, _, _ in
        guard status == noErr,
              let refCon,
              let imageBuffer else { return }

        let decoder = Unmanaged<LiveFileWritingDecoder>.fromOpaque(refCon).takeUnretainedValue()
        decoder.handleDecodedImageBuffer(imageBuffer)
    }
}

extension LiveFileWritingDecoder: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            guard let inputStream = aStream as? InputStream else { return }
            readAvailableBytes(from: inputStream)

        case .errorOccurred:
            onStatus?("Stream error: \(aStream.streamError?.localizedDescription ?? "unknown")")

        case .endEncountered:
            onStatus?("Livestream ended.")
            stop()

        default:
            break
        }
    }
}

private extension CMVideoFormatDescription {
    func matches(sps: Data, pps: Data) -> Bool {
        guard let currentSPS = parameterSet(at: 0), let currentPPS = parameterSet(at: 1) else {
            return false
        }
        return currentSPS == sps && currentPPS == pps
    }

    func parameterSet(at index: Int) -> Data? {
        var parameterSetPointer: UnsafePointer<UInt8>?
        var parameterSetSize = 0
        var parameterSetCount = 0
        var nalUnitHeaderLength: Int32 = 0

        let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            self,
            parameterSetIndex: index,
            parameterSetPointerOut: &parameterSetPointer,
            parameterSetSizeOut: &parameterSetSize,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )

        guard status == noErr, let parameterSetPointer else { return nil }
        return Data(bytes: parameterSetPointer, count: parameterSetSize)
    }
}
