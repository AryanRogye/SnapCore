//
//  MetalHelpers.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Metal
import MetalKit
import CoreImage

public enum MetalHelperError: Error {
    case invalidTextureCache
    case unsupportedPixelBufferFormat(String)
    case invalidDimensions(String)
}

public struct MetalHelpers {
    
    private static let textureCache: CVMetalTextureCache? = {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, MetalContext.shared.device, nil, &cache)
        return cache
    }()

    private static let supportedPixelBufferFormat: OSType = kCVPixelFormatType_32BGRA
    
    public static func getImageTexture(from pixelBuffer: CVPixelBuffer) throws -> MTLTexture? {
        guard let cache = textureCache else {
            throw MetalHelperError.invalidTextureCache
        }

        // This helper currently supports only single-plane BGRA buffers.
        // If other formats are needed (for example YCbCr bi-planar buffers),
        // conversion must be handled before creating a Metal texture.
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard pixelFormat == supportedPixelBufferFormat else {
            throw MetalHelperError.unsupportedPixelBufferFormat("Pixel Format Expected: \(supportedPixelBufferFormat), Given: \(pixelFormat)")
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard width > 0, height > 0 else {
            throw MetalHelperError.invalidDimensions("Invalid Width or Height (Width: \(width), Height: \(height)")
        }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        
        if status == kCVReturnSuccess, let cvTexture = cvTexture {
            return CVMetalTextureGetTexture(cvTexture)
        }
        
        return nil
    }
    
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
