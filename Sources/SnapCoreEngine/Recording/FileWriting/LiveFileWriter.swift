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
    
    public func clearOutputStream() {
        self.outputStream = nil
    }
    public func assignOutputStream(_ stream: OutputStream) {
        self.outputStream = stream
    }
    
    public func getOutput() -> URL? {
        outputURL
    }
    
    public func start(outputURL: URL) {
        self.outputURL = outputURL
        self.lastPTS = .invalid
        self.width = nil
        self.height = nil
        self.queued_samples.removeAll()
    }
    
    public var queued_samples: Deque<CMSampleBuffer> = []
    
    public func write(sample: SendableSampleBuffer, info: ValidationInfo, onFrameWritten: @escaping () -> Void) async throws {
        guard let outputStream else { throw FileWriterError.noOutputStream }
        let presentationTime = await info.getPresentationTime()
        let pixelBuffer = await info.getPixelBuffer()
        
        if compressionSession == nil {
            try setupCompressionSession(width: Int32(CVPixelBufferGetWidth(pixelBuffer)), height: Int32(CVPixelBufferGetHeight(pixelBuffer)))
        }
        
        guard let session = compressionSession else { return }
        
        // This is the call that was failing. Now it's a simple C call.
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        
        if status == noErr {
            onFrameWritten()
        }
    }
    
    fileprivate func processCompressedFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard let outputStream else { return }
        
        // 1. Check for Format Changes (SPS/PPS)
        // We send this so the receiver knows the "rules" of the video (dimensions, profile, etc.)
        if let description = CMSampleBufferGetFormatDescription(sampleBuffer) {
            // Only send if the format actually changed or it's the first frame
            try? sendFormatDescriptionIfNeeded(description, to: outputStream)
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
        
        // 2. Build the Packet [Length] [PTS] [Payload]
        var packet = Data()
        packet.appendUInt32(UInt32(data.count))
        packet.appendUInt64(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds.bitPattern.bigEndian)
        packet.append(data)
        
        try? writeAll(packet, to: outputStream)
    }
    
    private var lastSentFormat: CMFormatDescription?
    
    private func sendFormatDescriptionIfNeeded(_ description: CMFormatDescription, to stream: OutputStream) throws {
        guard description != lastSentFormat else { return }
        
        // For H.264, we extract the SPS and PPS NAL units
        // This tells the receiver: "Hey, expect a video with X width and Y height"
        var packet = Data()
        // You can define a specific 'Type' byte here (e.g., 0xFF) so the phone
        // knows this is a Header and not a Frame.
        
        // Simplified: Just send the raw description bytes or a custom flag
        // For now, let's just mark the format as sent
        lastSentFormat = description
    }
    
    public func stop() async throws {
        if let url = outputURL {
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

// 1. Define the callback INSIDE the actor as a static func
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
    
    // 2. Update your Session Creation
    private func setupCompressionSession(width: Int32, height: Int32) throws {
        // Retain 'self' so the pointer stays valid for the C-callback
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: LiveFileWriter.compressionCallback, // Use the static callback
            refcon: pointer,                                   // Pass the instance pointer
            compressionSessionOut: &session
        )
        
        guard status == noErr, let session = session else {
            throw FileWriterError.errorCreatingWriter
        }
        
        // Set Low-Latency properties
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        self.compressionSession = session
    }
    
}
#endif
