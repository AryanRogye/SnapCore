//
//  PlaybackImageCoordinator+Output.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage

#if os(macOS)
extension PlaybackImageCoordinator {
    
    private static let ciContext = CIContext(mtlDevice: MetalContext.shared.device)
    
    internal func getCGImage(from texture: MTLTexture) -> CGImage? {
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        
        return Self.ciContext.createCGImage(flipped, from: flipped.extent)
    }
    internal func updateDisplayedFrames(
        original: MTLTexture,
        lanczosed: MTLTexture?,
        contrasted: MTLTexture?,
        sharpened: MTLTexture?,
        baseForSharpness: MTLTexture,
        cursored: MTLTexture?
    ) {
        let displayed = resolveDisplayedTextures(
            original: original,
            lanczosed: lanczosed,
            contrasted: contrasted,
            sharpened: sharpened,
            baseForSharpness: baseForSharpness,
            cursored: cursored
        )
        
        originalCurrentFrame = getCGImage(from: displayed.original)
        currentFrame = getCGImage(from: displayed.main)
        
        if let lanczosed = displayed.lanczosed {
            currentLanczosFrame = getCGImage(from: lanczosed)
        } else {
            currentLanczosFrame = nil
        }
        
        if let contrasted = displayed.contrasted {
            currentContrastedFrame = getCGImage(from: contrasted)
        } else {
            currentContrastedFrame = nil
        }
        
        if let sharpened = displayed.sharpened {
            currentSharpenedFrame = getCGImage(from: sharpened)
        } else {
            currentSharpenedFrame = nil
        }
    }
    
    private func resolveDisplayedTextures(
        original: MTLTexture,
        lanczosed: MTLTexture?,
        contrasted: MTLTexture?,
        sharpened: MTLTexture?,
        baseForSharpness: MTLTexture,
        cursored: MTLTexture?
    ) -> (
        original: MTLTexture,
        main: MTLTexture,
        lanczosed: MTLTexture?,
        contrasted: MTLTexture?,
        sharpened: MTLTexture?
    ) {
        let contrastPreview = contrastSideBySide ? contrasted : nil
        let sharpnessPreview = sharpnessSideBySide ? sharpened : nil
        let lanczosPreview = lanczosSideBySide ? lanczosed : nil
        
        let mainTexture: MTLTexture
        
        if sharpnessSideBySide {
            mainTexture = cursored ?? baseForSharpness
        } else if let cursored {
            mainTexture = cursored
        } else if let sharpened {
            mainTexture = sharpened
        } else if let contrasted {
            mainTexture = contrasted
        } else if let lanczosed {
            mainTexture = lanczosed
        } else {
            mainTexture = original
        }
        
        return (
            original: original,
            main: mainTexture,
            lanczosed: lanczosPreview,
            contrasted: contrastPreview,
            sharpened: sharpnessPreview
        )
    }
}
#endif
