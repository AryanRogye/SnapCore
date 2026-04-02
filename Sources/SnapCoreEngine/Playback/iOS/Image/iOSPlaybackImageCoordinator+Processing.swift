//
//  iOSPlaybackImageCoordinator+Processing.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/31/26.
//

#if os(iOS)

import AVFoundation

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
            cursorTexture: nil,
            isLanczosUpscalingEnabled: isAdjustingLanczosScale,
            isContrastEnabled: isAdjustingContrast,
            isSharpeningEnabled: isAdjustingSharpness,
            isStichingCursorEnabled: false,
            frame: nil,
            lanczosScale: lanczosScale,
            kernelSize: kernelSize,
            contrast: contrast,
            sharpness: sharpness,
            currentMouse: nil,
            cursorShadowConfig: nil,
            cursorMotionState: nil
        )
        
        updateDisplayedFrames(from: result)
//        currentFrameColor = imageColorProcessor.getDominantColor(from: original)
    }
}

#endif
