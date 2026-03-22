//
//  PlaybackImageCoordinator+Output.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage

extension PlaybackImageCoordinator {
    internal func updateDisplayedFrames(
        original: CGImage,
        contrasted: CGImage?,
        sharpened: CGImage?,
        baseForSharpness: CGImage
    ) {
        self.originalCurrentFrame = original
        if contrastSideBySide {
            currentContrastedFrame = contrasted
        } else {
            currentContrastedFrame = nil
        }
        
        if sharpnessSideBySide {
            currentFrame = baseForSharpness
            currentSharpenedFrame = sharpened
        } else {
            currentSharpenedFrame = nil
            currentFrame = sharpened ?? baseForSharpness
        }
        
        if !contrastSideBySide && sharpened == nil && contrasted == nil {
            currentFrame = original
        }
    }
}
