//
//  MetalHelpers.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Metal
import MetalKit
import CoreImage

struct MetalHelpers {
    public static func getImageTexture(
        from cgImage: CGImage
    ) throws -> MTLTexture? {
        let loader = MTKTextureLoader(device: MetalContext.shared.device)
        
        let tex = try loader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: false as NSNumber,
                .generateMipmaps: true as NSNumber,
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.shared.rawValue)
            ]
        )
        
        return tex
    }
}
