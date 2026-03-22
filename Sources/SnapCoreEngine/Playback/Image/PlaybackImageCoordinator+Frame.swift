//
//  PlaybackImageCoordinator+Frame.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage
import CoreMedia

extension PlaybackImageCoordinator {
    
    /// Function gets the frame info from the time
    @MainActor
    internal func getFrameInfo(
        _ time: CMTime
    ) -> FrameInfo? {
        /// Make sure we have frames
        guard let firstFrameTime = recordingInfo.frames.first?.time else { return nil }
        
        /// Find the frame where its relative time (absolute - start) matches the player time
        if let frame = recordingInfo.frames.last(where: {
            let relativeFrameTime = CMTimeSubtract($0.time, firstFrameTime)
            return relativeFrameTime <= time
        }) {
            return frame
        }
        
        /// Fallback
        return recordingInfo.frames.first
    }
    
    /// Function Converts a CVPixelBuffer to a CGImage
    internal func getCG(
        from pixelBuffer: CVPixelBuffer
    ) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
