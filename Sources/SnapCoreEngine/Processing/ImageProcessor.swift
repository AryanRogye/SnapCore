//
//  ImageProcessor.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/27/26.
//

import MetalKit

public struct ImageProcessorResult {
    public var original: MTLTexture
    public var LanczosTexture: MTLTexture?
    public var contrastTexture: MTLTexture?
    public var sharpeningTexture: MTLTexture?
    /// this would be the output texture
    public var stitchingCursorTexture: MTLTexture?
    
    public init(original: MTLTexture) {
        self.original = original
    }
}

public final class ImageProcessor {
    
    let cursorSticher = CursorSticher()
    let lanczosUpscaler = LanczosUpscaler()
    let imageContrastBooster = ImageContrastBooster()
    let imageSharpener = ImageSharpener()
    
    public init() { }
    
    public func process(
        _ texture: MTLTexture,
        cursorTexture: MTLTexture?,
        isLanczosUpscalingEnabled: Bool,
        isContrastEnabled: Bool,
        isSharpeningEnabled: Bool,
        isStichingCursorEnabled: Bool,
        frame: CGRect?,
        lanczosScale: CGFloat,
        kernelSize: CGFloat,
        contrast: CGFloat,
        sharpness: CGFloat,
        currentMouse: CurrentMouseInfo?,
        cursorShadowConfig: CursorShadowConfig?,
        cursorMotionState: CursorMotionState?,
    ) -> ImageProcessorResult {
        return process(texture,
                       cursorTexture: cursorTexture,
                       isLanczosUpscalingEnabled: isLanczosUpscalingEnabled,
                       isContrastEnabled: isContrastEnabled,
                       isSharpeningEnabled: isSharpeningEnabled,
                       isStichingCursorEnabled: isStichingCursorEnabled,
                       frame: frame,
                       lanczosScale: lanczosScale,
                       kernelSize: kernelSize,
                       contrast: contrast,
                       sharpness: sharpness,
                       currentMouse: currentMouse,
                       cursorShadowConfig: cursorShadowConfig ?? CursorShadowConfig(),
                       cursorMotionState: cursorMotionState ?? CursorMotionState()
        )
    }
    
    public func process(
        _ texture: MTLTexture,
        cursorTexture: MTLTexture?,
        isLanczosUpscalingEnabled: Bool,
        isContrastEnabled: Bool,
        isSharpeningEnabled: Bool,
        isStichingCursorEnabled: Bool,
        frame: CGRect?,
        lanczosScale: CGFloat,
        kernelSize: CGFloat,
        contrast: CGFloat,
        sharpness: CGFloat,
        currentMouse: CurrentMouseInfo?,
        cursorShadowConfig: CursorShadowConfig,
        cursorMotionState: CursorMotionState,
    ) -> ImageProcessorResult {
        var result = ImageProcessorResult(original: texture)
        
        // step 1 would be the Lanczos Upscaling
        let lanczos = self.getLanczosUpscaled(
            texture,
            lanczosScale: lanczosScale,
            kernelSize: kernelSize,
            isEnabled: isLanczosUpscalingEnabled
        )
        result.LanczosTexture = lanczos
        
        // step 2 would be the Lanczos Upscaling
        let contrasted = self.getContrastedImage(
            lanczos ?? texture,
            contrast: contrast,
            isEnabled: isContrastEnabled
        )
        result.contrastTexture = contrasted
        
        // step 3 would be the sharpness
        let sharpened = self.getSharpenedImage(
            contrasted ?? lanczos ?? texture,
            sharpness: sharpness,
            isEnabled: isSharpeningEnabled
        )
        result.sharpeningTexture = sharpened
        
        // step 4 would be the cursor stiching
        let stiched = self.getCursoredImage(
            sharpened ?? contrasted ?? lanczos ?? texture,
            cursorTexture: cursorTexture,
            currentMouse: currentMouse,
            cursorShadowConfig: cursorShadowConfig,
            cursorMotionState: cursorMotionState,
            frame: frame,
            isEnabled: isStichingCursorEnabled
        )
        result.stitchingCursorTexture = stiched
        
        return result
    }
}

extension ImageProcessor {
    
    private func getCursoredImage(
        _ image: MTLTexture,
        cursorTexture: MTLTexture?,
        currentMouse: CurrentMouseInfo?,
        cursorShadowConfig: CursorShadowConfig,
        cursorMotionState: CursorMotionState,
        frame: CGRect?,
        isEnabled: Bool
    ) -> MTLTexture? {
        
        /// if we recorded with the cursor return nil
        guard isEnabled else { return nil }
        
        guard let cursorTexture,
              let point = currentMouse?.point,
              let frame
        else { return nil }
        
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
     * Function Checks to make sure that we're adjusting the Lanczos upscale if we're not we return nil
     * or else we try to get it
     */
    private func getLanczosUpscaled(
        _ image: MTLTexture,
        lanczosScale: CGFloat,
        kernelSize: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
            return nil
        }
        return lanczosUpscaler.upscale(
            image,
            lanczosScale: Float(lanczosScale),
            kernelSize: Int(kernelSize)
            
        )
    }
    
    /**
     * Function Checks to make sure that we're adjusting contrast if we're not we return nil
     * or else we try to get the contrast
     */
    private func getContrastedImage(
        _ image: MTLTexture,
        contrast: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
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
        _ image: MTLTexture,
        sharpness: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
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
