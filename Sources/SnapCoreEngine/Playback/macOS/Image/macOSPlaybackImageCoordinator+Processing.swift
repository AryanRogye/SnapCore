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
    
    /// original → lanczos → contrast → sharpness → cursor
    @MainActor
    internal func processImage(cgImage: CGImage) throws {
        let original = cgImage
        guard let originalTexture = try MetalHelpers.getImageTexture(from: original) else { return }
        
        let result = imageProcessor.process(
            originalTexture,
            cursorTexture: cursorTexture,
            isLanczosUpscalingEnabled: isAdjustingLanczosScale,
            isContrastEnabled: isAdjustingContrast,
            isSharpeningEnabled: isAdjustingSharpness,
            isStichingCursorEnabled: recordingInfo.isUsingCustomCursor,
            frame: recordingInfo.frame,
            lanczosScale: lanczosScale,
            kernelSize: kernelSize,
            contrast: contrast,
            sharpness: sharpness,
            currentMouse: currentMouse,
            cursorShadowConfig: cursorShadowConfig,
            cursorMotionState: cursorMotionState
        )
        
        updateDisplayedFrames(from: result)
        
        currentFrameColor = imageColorProcessor.getDominantColor(from: original)
    }
}
#endif
