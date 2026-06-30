//
//  StreamOutput.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit

public struct SendableSampleBuffer: @unchecked Sendable {
    public let buffer: CMSampleBuffer
    
    /**
     * Returns true if complete, idle or started
     */
    public var shouldAppend: Bool {
        guard let status = getFrameStatus(sample: self) else {
            return true
        }
        
        switch status {
        case .complete, .idle, .started:
            return true
        case .blank, .suspended, .stopped:
            return false
        @unknown default:
            return false
        }
    }
    
    private func getFrameStatus(sample: SendableSampleBuffer) -> SCFrameStatus? {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sample.buffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
              let firstAttachment = attachments.first,
              let rawValue = firstAttachment[.status] as? Int else {
            return nil
        }
        
        return SCFrameStatus(rawValue: rawValue)
    }
}

final class StreamOutput: NSObject, SCStreamOutput {
    private let (screenStream, screenContinuation) = AsyncStream<SendableSampleBuffer>.makeStream()
    private let (audioStream, audioContinuation) = AsyncStream<SendableSampleBuffer>.makeStream()
    
    var screenFrames: AsyncStream<SendableSampleBuffer> { screenStream }
    var audioFrames: AsyncStream<SendableSampleBuffer> { audioStream }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        switch type {
        case .screen: screenContinuation.yield(SendableSampleBuffer(buffer: sampleBuffer))
        case .audio:  audioContinuation.yield(SendableSampleBuffer(buffer: sampleBuffer))
        default: break
        }
    }
}
#endif
