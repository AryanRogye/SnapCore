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
    public var exposureTexture: MTLTexture?
    public var contrastTexture: MTLTexture?
    public var blurTexture: MTLTexture?
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
    let exposureAdjuster = ImageExposureAdjuster()
    let imageBlurrer = ImageBlurrer()
    
    public init() { }
    
    public func process(
        _ texture: MTLTexture,
        cursorTexture: MTLTexture? = nil,
        isLanczosUpscalingEnabled: Bool,
        isContrastEnabled: Bool,
        isExposureEnabled: Bool,
        isSharpeningEnabled: Bool,
        isBlurEnabled: Bool = false,
        isStichingCursorEnabled: Bool,
        frame: CGRect? = nil,
        lanczosScale: CGFloat,
        kernelSize: Int,
        contrast: CGFloat,
        exposure: CGFloat,
        blur: Int = 0,
        blurDetail: CGFloat = 0,
        sharpness: CGFloat,
        sharpnessRadius: Int = 1,
        sharpnessDetail: CGFloat = 0.1,
        currentMouse: CurrentMouseInfo? = nil,
        cursorShadowConfig: CursorShadowConfig? = nil,
        cursorMotionState: CursorMotionState? = nil,
        statusCompletionHandler: @escaping (String) -> Void = { _ in }
    ) -> ImageProcessorResult {
        return process(texture,
                       cursorTexture: cursorTexture,
                       isLanczosUpscalingEnabled: isLanczosUpscalingEnabled,
                       isContrastEnabled: isContrastEnabled,
                       isExposureEnabled: isExposureEnabled,
                       isSharpeningEnabled: isSharpeningEnabled,
                       isBlurEnabled: isBlurEnabled,
                       isStichingCursorEnabled: isStichingCursorEnabled,
                       frame: frame,
                       lanczosScale: lanczosScale,
                       kernelSize: kernelSize,
                       contrast: contrast,
                       exposure: exposure,
                       blur: blur,
                       blurDetail: blurDetail,
                       sharpness: sharpness,
                       sharpnessRadius: sharpnessRadius,
                       sharpnessDetail: sharpnessDetail,
                       currentMouse: currentMouse,
                       cursorShadowConfig: cursorShadowConfig ?? CursorShadowConfig(),
                       cursorMotionState: cursorMotionState ?? CursorMotionState(),
                       statusCompletionHandler: statusCompletionHandler
        )
    }
    
    public func process(
        _ texture: MTLTexture,
        cursorTexture: MTLTexture?,
        isLanczosUpscalingEnabled: Bool,
        isContrastEnabled: Bool,
        isExposureEnabled: Bool,
        isSharpeningEnabled: Bool,
        isBlurEnabled: Bool = false,
        isStichingCursorEnabled: Bool,
        frame: CGRect?,
        lanczosScale: CGFloat,
        kernelSize: Int,
        contrast: CGFloat,
        exposure: CGFloat,
        blur: Int = 0,
        blurDetail: CGFloat = 0,
        sharpness: CGFloat,
        sharpnessRadius: Int = 1,
        sharpnessDetail: CGFloat = 0.1,
        currentMouse: CurrentMouseInfo?,
        cursorShadowConfig: CursorShadowConfig,
        cursorMotionState: CursorMotionState,
        statusCompletionHandler:  @escaping (String) -> Void = { _ in }
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
        if isLanczosUpscalingEnabled {
            statusCompletionHandler("Lanczos Upscaling Result: \(lanczos != nil) - \(lanczosScale) Scale - \(kernelSize) Kernel Size")
        }
        
        // step 2 would be the Exposure
        let exposured = self.getExposuredImage(
            lanczos ?? texture,
            factor: exposure,
            isEnabled: isExposureEnabled
        )
        result.exposureTexture = exposured
        if isExposureEnabled && exposure > 0 {
            statusCompletionHandler("Exposure Result: \(exposured != nil) - \(exposure) exposure")
        }
        
        // step 3 would be the Contrast
        let contrasted = self.getContrastedImage(
            exposured ?? lanczos ?? texture,
            contrast: contrast,
            isEnabled: isContrastEnabled
        )
        result.contrastTexture = contrasted
        if isContrastEnabled && contrast > 0 {
            statusCompletionHandler("Contrast Result: \(contrasted != nil) - \(contrast) contrast")
        }
        
        /// Blur
        let blurred = self.getBlurredImage(
            contrasted ?? exposured ?? lanczos ?? texture,
            radius: blur,
            detail: blurDetail,
            isEnabled: isBlurEnabled
        )
        result.blurTexture = blurred
        if isBlurEnabled {
            statusCompletionHandler("Blur Result: \(blurred != nil) - \(blur) blur \(blurDetail) detail")
        }
        
        // step 4 would be the sharpness
        let sharpened = self.getSharpenedImage(
            blurred ?? contrasted ?? exposured ?? lanczos ?? texture,
            sharpness: sharpness,
            sharpnessRadius: sharpnessRadius,
            sharpnessDetail: sharpnessDetail,
            isEnabled: isSharpeningEnabled
        )
        result.sharpeningTexture = sharpened
        if isSharpeningEnabled {
            statusCompletionHandler("Sharpness Result: \(sharpened != nil) - \(sharpness) sharpness \(sharpnessRadius) radius \(sharpnessDetail) detail")
        }
        
        // step 5 would be the cursor stiching
        let stiched = self.getCursoredImage(
            sharpened ?? blurred ?? contrasted ?? exposured ?? lanczos ?? texture,
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
        kernelSize: Int,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
            return nil
        }
        return lanczosUpscaler.upscale(
            image,
            lanczosScale: Float(lanczosScale),
            kernelSize: kernelSize
            
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
     * Function Checks to make sure that we're adjusting exposure if we're not we return nil
     * or else we try to get the exposure
     */
    private func getExposuredImage(
        _ image: MTLTexture,
        factor: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
            return nil
        }
        do {
            return try exposureAdjuster.adjustExposure(for: image, factor: Float(factor))
        } catch {
            print("Error applying exposure: \(error)")
            return nil
        }
    }
    
    /**
     * Function Checks to make sure that we're adjusting blur if we're not we return nil
     * or else we try to get the sharpness
     */
    private func getBlurredImage(
        _ image: MTLTexture,
        radius: Int,
        detail: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
            return nil
        }
        do {
            return try imageBlurrer.applyBlur(
                for: image,
                radius: radius,
                detail: Float(detail)
            )
        } catch {
            print("Error sharpening image: \(error)")
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
        sharpnessRadius: Int,
        sharpnessDetail: CGFloat,
        isEnabled: Bool
    ) -> MTLTexture? {
        guard isEnabled else {
            return nil
        }
        do {
            return try imageSharpener.sharpen(
                image,
                sharpness: Float(sharpness),
                radius: sharpnessRadius,
                detail: Float(sharpnessDetail)
            )
        } catch {
            print("Error sharpening image: \(error)")
            return nil
        }
    }
}
