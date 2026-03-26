//
//  SampleValidator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#if os(macOS)
import AVFoundation
import SnapCore

actor ValidationInfo {
    var pixelBuffer: CVPixelBuffer
    var presentationTime: CMTime
    
    init(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        self.pixelBuffer = pixelBuffer
        self.presentationTime = presentationTime
    }
    
    public func getPixelBuffer() -> CVPixelBuffer {
        pixelBuffer
    }
    
    public func getPresentationTime() -> CMTime {
        presentationTime
    }
}

final class SampleValidator {
    public static func isValidSample(
        _ sample : SendableSampleBuffer
    ) -> ValidationInfo? {
        guard CMSampleBufferDataIsReady(sample.buffer) else {
            return nil
        }
        guard sample.shouldAppend else {
            return nil
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample.buffer) else {
            return nil
        }
        
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample.buffer)
        guard presentationTime.isValid else {
            return nil
        }
        
        return ValidationInfo(
            pixelBuffer: pixelBuffer,
            presentationTime: presentationTime
        )
    }
    
    public static func isValidSample(
        lastPTS: CMTime,
        presentationTime: CMTime
    ) -> Bool {
        if !lastPTS.isValid { return true }
        return CMTimeCompare(presentationTime, lastPTS) > 0
    }
}
#endif
