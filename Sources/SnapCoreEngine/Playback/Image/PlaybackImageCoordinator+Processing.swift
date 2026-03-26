//
//  PlaybackImageCoordinator+Processing.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import AVFoundation

#if os(macOS)
extension PlaybackImageCoordinator {
    @MainActor
    internal func processImage(pixelBuffer: CVPixelBuffer) {
        guard let original = getCG(from: pixelBuffer) else { return }
        do {
            try self.processImage(cgImage: original)
        } catch {
            print("Error Processing Image: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    internal func processImage(cgImage: CGImage) throws {
        let original = cgImage
        guard let originalTexture = try MetalHelpers.getImageTexture(from: original) else { return }
        
        let contrasted = getContrastedImage(originalTexture)
        let baseForSharpness = contrasted ?? originalTexture
        let sharpened = getSharpenedImage(baseForSharpness)
        let baseForCursor = sharpened ?? baseForSharpness
        let cursored = getCursoredImage(baseForCursor) ?? baseForCursor
        
        updateDisplayedFrames(
            original: originalTexture,
            contrasted: contrasted,
            sharpened: sharpened,
            baseForSharpness: baseForSharpness,
            cursored: cursored
        )
        
        currentFrameColor = imageColorProcessor.getDominantColor(from: original)
    }
    
    @MainActor
    private func getCursoredImage(
        _ image: MTLTexture
    ) -> MTLTexture? {
        
        /// if we recorded with the cursor return nil
        guard recordingInfo.isUsingCustomCursor else { return nil }
        
        guard let cursorTexture,
              let point = currentMouse?.point,
              let frame = recordingInfo.frame else { return nil }
        do {
            return try cursorSticher.apply(
                cursorTexture,
                onto: image,
                at: point,
                screen: frame,
                shadowConfig: cursorShadowConfig,
                cursorMotionState: cursorMotionState
            )
        } catch {
            print("Error Applying Cursor")
            return nil
        }
    }
    
    /**
     * Function Checks to make sure that we're adjusting contrast if we're not we return nil
     * or else we try to get the contrast
     */
    private func getContrastedImage(
        _ image: MTLTexture
    ) -> MTLTexture? {
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
        _ image: MTLTexture
    ) -> MTLTexture? {
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
#endif
