//
//  LiveFileWriter.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

#if os(macOS)
import AVFoundation
import ScreenCaptureKit
import Collections
import DequeModule
import SnapCore
import VideoToolbox

actor LiveFileWriter: FileWriter {

    var outputStream        : OutputStream?
    var width               : CGFloat? = nil
    var height              : CGFloat? = nil
    var outputURL           : URL? = nil
    var lastPTS             : CMTime = .invalid
    var sessionStartTime    : CMTime = .invalid

    private var compressionSession: VTCompressionSession?

    /// The expected frame rate for encoder configuration (Phase 2)
    private var expectedFPS: Int = 30

    /// Stored closure so the compression callback can invoke it after
    /// the packet is actually written, not just submitted (Phase 1)
    private var pendingFrameWritten: (() -> Void)?

    // MARK: - Bounded Packet Queue (Phase 4)

    /// Each queued entry carries the raw packet bytes and whether it is a keyframe.
    private struct QueuedPacket {
        let data: Data
        let isKeyframe: Bool
    }

    /// Bounded queue – capped at `maxQueuedPackets`.
    private var packetQueue: Deque<QueuedPacket> = []

    /// Maximum number of packets we allow in the queue before dropping.
    private let maxQueuedPackets = 10

    /// Whether the output stream currently has space available.
    private var streamReady = true

    public func clearOutputStream() {
        self.outputStream = nil
    }
    public func assignOutputStream(_ stream: OutputStream) {
        self.outputStream = stream
    }

    public func getOutput() -> URL? {
        outputURL
    }

    public func start(outputURL: URL, expectedFPS: Int = 30) {
        self.outputURL = outputURL
        self.lastPTS = .invalid
        self.width = nil
        self.height = nil
        self.expectedFPS = expectedFPS
        self.queued_samples.removeAll()
        self.packetQueue.removeAll()
        self.lastSentFormat = nil
        self.streamReady = true
    }

    public var queued_samples: Deque<CMSampleBuffer> = []

    public func write(sample: SendableSampleBuffer, info: ValidationInfo, onFrameWritten: @escaping () -> Void) async throws {
        guard let _ = outputStream else { throw FileWriterError.noOutputStream }
        let presentationTime = await info.getPresentationTime()
        let pixelBuffer = await info.getPixelBuffer()

        if compressionSession == nil {
            try setupCompressionSession(width: Int32(CVPixelBufferGetWidth(pixelBuffer)), height: Int32(CVPixelBufferGetHeight(pixelBuffer)))
        }

        guard let session = compressionSession else { return }

        // Phase 1: Store the callback so it fires AFTER the packet is written,
        // not when the frame is merely submitted to the encoder.
        self.pendingFrameWritten = onFrameWritten

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            self.pendingFrameWritten = nil
        }
    }

    fileprivate func processCompressedFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard let outputStream else { return }

        // Phase 3: Send SPS/PPS control packet when format changes
        if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
            sendFormatDescriptionIfNeeded(description, to: outputStream)
        }

        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        let length = CMBlockBufferGetDataLength(dataBuffer)
        var data = Data(count: length)

        _ = data.withUnsafeMutableBytes { (dest: UnsafeMutableRawBufferPointer) in
            CMBlockBufferCopyDataBytes(
                dataBuffer,
                atOffset: 0,
                dataLength: length,
                destination: dest.baseAddress!
            )
        }

        // Determine if this is a keyframe
        let isKeyframe: Bool = {
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
                  let first = attachments.first else {
                return true // If no attachments, treat as keyframe (IDR)
            }
            // kCMSampleAttachmentKey_NotSync == true means it is NOT a sync (key) frame
            if let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool {
                return !notSync
            }
            return true
        }()

        // Build the Packet: [Length (4 bytes)] [PTS (8 bytes)] [Payload]
        var packet = Data()
        packet.appendUInt32(UInt32(data.count))
        packet.appendUInt64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds.bitPattern.bigEndian)
        packet.append(data)

        // Phase 4: Enqueue instead of blocking write
        enqueuePacket(QueuedPacket(data: packet, isKeyframe: isKeyframe))
        drainQueue(to: outputStream)

        // Phase 1: Signal frame written only after the packet is enqueued/written
        pendingFrameWritten?()
        pendingFrameWritten = nil
    }

    // MARK: - SPS/PPS Control Packet (Phase 3)

    private var lastSentFormat: CMFormatDescription?

    /// Extracts SPS/PPS from the format description and sends a control packet
    /// with header byte 0xFF so the decoder can distinguish it from video packets.
    private func sendFormatDescriptionIfNeeded(_ description: CMFormatDescription, to stream: OutputStream) {
        guard description != lastSentFormat else { return }
        lastSentFormat = description

        // Extract SPS
        var spsPointer: UnsafePointer<UInt8>?
        var spsSize = 0
        var parameterSetCount = 0
        var nalUnitHeaderLength: Int32 = 0

        let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            description,
            parameterSetIndex: 0,
            parameterSetPointerOut: &spsPointer,
            parameterSetSizeOut: &spsSize,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )

        guard spsStatus == noErr, let spsPtr = spsPointer else { return }

        // Extract PPS
        var ppsPointer: UnsafePointer<UInt8>?
        var ppsSize = 0

        let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            description,
            parameterSetIndex: 1,
            parameterSetPointerOut: &ppsPointer,
            parameterSetSizeOut: &ppsSize,
            parameterSetCountOut: nil,
            nalUnitHeaderLengthOut: nil
        )

        guard ppsStatus == noErr, let ppsPtr = ppsPointer else { return }

        let spsData = Data(bytes: spsPtr, count: spsSize)
        let ppsData = Data(bytes: ppsPtr, count: ppsSize)

        // Control packet format:
        // [0xFF marker (1 byte)] [SPS length (2 bytes)] [SPS] [PPS length (2 bytes)] [PPS]
        var controlPacket = Data()
        controlPacket.append(0xFF) // marker byte
        controlPacket.appendUInt16(UInt16(spsData.count))
        controlPacket.append(spsData)
        controlPacket.appendUInt16(UInt16(ppsData.count))
        controlPacket.append(ppsData)

        // Wrap in a framed packet: [total length (4 bytes)] [control packet]
        // Use a special "zero PTS" sentinel so the decoder knows this is not a video packet.
        var framedPacket = Data()
        framedPacket.appendUInt32(UInt32(controlPacket.count))
        // PTS slot: all 0xFF bytes as sentinel (impossible real PTS)
        framedPacket.appendUInt64(UInt64.max)
        framedPacket.append(controlPacket)

        // Write control packet directly (small, critical, must not be dropped)
        try? writeAll(framedPacket, to: stream)
    }

    // MARK: - Bounded Queue (Phase 4)

    private func enqueuePacket(_ packet: QueuedPacket) {
        // If the queue is full, drop the oldest non-keyframe packet
        while packetQueue.count >= maxQueuedPackets {
            if let dropIndex = packetQueue.firstIndex(where: { !$0.isKeyframe }) {
                packetQueue.remove(at: dropIndex)
            } else {
                // All keyframes — drop the oldest one
                packetQueue.removeFirst()
            }
        }
        packetQueue.append(packet)
    }

    private func drainQueue(to stream: OutputStream) {
        while let packet = packetQueue.first {
            if stream.hasSpaceAvailable {
                do {
                    try writeAll(packet.data, to: stream)
                    packetQueue.removeFirst()
                } catch {
                    // Stream not writable right now, stop draining
                    break
                }
            } else {
                break
            }
        }
    }

    // MARK: - Stop / Teardown (Phase 6)

    public func stop() async throws {
        // Flush pending frames before invalidation
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
        lastSentFormat = nil
        packetQueue.removeAll()

        if let _ = outputURL {
            queued_samples.removeAll()
        }
    }

    private func getWidthAndHeight(
        pixelBuffer: CVPixelBuffer
    ) -> (width: CGFloat, height: CGFloat) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return (CGFloat(width), CGFloat(height))
    }

    private func writeAll(_ data: Data, to stream: OutputStream) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw FileWriterError.errorWritingToFile("Could not access packet bytes")
            }

            var totalWritten = 0

            while totalWritten < data.count {
                let written = stream.write(
                    baseAddress.advanced(by: totalWritten),
                    maxLength: data.count - totalWritten
                )

                if written < 0 {
                    throw FileWriterError.errorWritingToFile(
                        "Stream write failed: \(stream.streamError?.localizedDescription ?? "unknown error")"
                    )
                }

                if written == 0 {
                    throw FileWriterError.errorWritingToFile("Stream write returned 0 bytes")
                }

                totalWritten += written
            }
        }
    }
}


private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }

    mutating func appendUInt64(_ value: UInt64) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { bytes in
            append(bytes.bindMemory(to: UInt8.self))
        }
    }
}

// MARK: - Compression Callback & Session Setup
extension LiveFileWriter {
    private static let compressionCallback: VTCompressionOutputCallback = { (
        outputCallbackRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
    ) in
        guard status == noErr, let buffer = sampleBuffer, let refCon = outputCallbackRefCon else { return }

        // Safely bridge the raw pointer back to the Actor instance
        let actor = Unmanaged<LiveFileWriter>.fromOpaque(refCon).takeUnretainedValue()

        // Hand the data back to the actor context
        Task {
            await actor.processCompressedFrame(buffer)
        }
    }

    // Phase 2: Full low-latency encoder configuration
    private func setupCompressionSession(width: Int32, height: Int32) throws {
        // Retain 'self' so the pointer stays valid for the C-callback
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        // Try low-latency rate control in the encoder specification
        let encoderSpec: CFDictionary = [
            kVTVideoEncoderSpecification_EnableLowLatencyRateControl: kCFBooleanTrue
        ] as CFDictionary

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: encoderSpec,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: LiveFileWriter.compressionCallback,
            refcon: pointer,
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw FileWriterError.errorCreatingWriter
        }

        // Low-latency properties
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        // Expected frame rate
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: expectedFPS))

        // Keyframe cadence: 1 second duration, or fps count
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: NSNumber(value: 1.0))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: expectedFPS))

        // Pre-allocate encoder resources before the first frame
        VTCompressionSessionPrepareToEncodeFrames(session)

        self.compressionSession = session
    }

}
#endif
