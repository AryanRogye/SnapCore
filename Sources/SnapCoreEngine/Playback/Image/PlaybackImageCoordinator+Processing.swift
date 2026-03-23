//
//  PlaybackImageCoordinator+Processing.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import AVFoundation

extension PlaybackImageCoordinator {
    internal func processImage(pixelBuffer: CVPixelBuffer) {
        guard let original = getCG(from: pixelBuffer) else { return }
        self.processImage(cgImage: original)
    }
    
    internal func processImage(cgImage: CGImage) {
        var original = cgImage
        let contrasted = getContrastedImage(original)
        let baseForSharpness = contrasted ?? original
        let sharpened = getSharpenedImage(baseForSharpness)
        
        updateDisplayedFrames(
            original: original,
            contrasted: contrasted,
            sharpened: sharpened,
            baseForSharpness: baseForSharpness
        )
        
        currentFrameColor = imageProcessor.getDominantColor(from: original)
    }
    
    /**
     * Function Checks to make sure that we're adjusting contrast if we're not we return nil
     * or else we try to get the contrast
     */
    private func getContrastedImage(
        _ image: CGImage
    ) -> CGImage? {
        guard isAdjustingContrast else {
            return nil
        }
        do {
            return try imageContrastBooster.boostContrast(for: image, factor: Float(contrast))
        } catch {
            print("Error applying contrast: \(error)")
            return nil
        }
    }
    
    /**
     * Function Checks to make sure that we're adjusting sharpness if we're not we return nil
     * or else we try to get the sharpness
     */
    private func getSharpenedImage(
        _ image: CGImage
    ) -> CGImage? {
        guard isAdjustingSharpness else {
            return nil
        }
        do {
            return try imageSharpener.sharpen(image, sharpness: Float(sharpness))
        } catch {
            print("Error sharpening image: \(error)")
            return nil
        }
    }
}
