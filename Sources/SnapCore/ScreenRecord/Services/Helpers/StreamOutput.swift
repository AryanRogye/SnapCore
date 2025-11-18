//
//  StreamOutput.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit

final class StreamOutput: NSObject, SCStreamOutput {
    var onScreenFrame: ((CMSampleBuffer) -> Void)?
    var onAudioFrame: ((CMSampleBuffer) -> Void)?
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        switch type {
        case .screen:
            onScreenFrame?(sampleBuffer)
        case .audio:
            onAudioFrame?(sampleBuffer)
        default:
            break
        }
    }
}

#endif
