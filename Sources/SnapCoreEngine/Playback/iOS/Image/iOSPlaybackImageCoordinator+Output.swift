//
//  PlaybackImageCoordinator+Output.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage

#if os(iOS)
extension PlaybackImageCoordinator {
    
    private static let ciContext = CIContext(mtlDevice: MetalContext.shared.device)
    
    internal func getCGImage(from texture: MTLTexture?) -> CGImage? {
        guard let texture else { return nil }
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        
        return Self.ciContext.createCGImage(flipped, from: flipped.extent)
    }
    
    internal func updateDisplayedFrames(
        from result: ImageProcessorResult
    ) {
        currentLanczosFrame = self.getCGImage(from: result.LanczosTexture)
        currentContrastedFrame = self.getCGImage(from: result.contrastTexture)
        currentSharpenedFrame = self.getCGImage(from: result.sharpeningTexture)
        originalCurrentFrame = self.getCGImage(from: result.original)
        currentFrame = self.getCGImage(from: result.stitchingCursorTexture)
            ?? currentSharpenedFrame
            ?? currentContrastedFrame
            ?? currentLanczosFrame
            ?? originalCurrentFrame
    }
}
#endif
