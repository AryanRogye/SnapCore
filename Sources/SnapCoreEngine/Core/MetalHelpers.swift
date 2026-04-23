//
//  MetalHelpers.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Metal
import MetalKit
import CoreImage
import SwiftUI

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
    
    public static func makeTexture(from pixelBuffer: CVPixelBuffer) throws -> MTLTexture? {
        guard let cache = textureCache else {
            throw MetalHelperError.invalidTextureCache
        }
        
        let cvPixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard width > 0, height > 0 else {
            throw MetalHelperError.invalidDimensions(
                "Invalid Width or Height (Width: \(width), Height: \(height))"
            )
        }
        
        let metalPixelFormat: MTLPixelFormat
        
        switch cvPixelFormat {
        case kCVPixelFormatType_32BGRA:
            metalPixelFormat = .bgra8Unorm
            
        case kCVPixelFormatType_OneComponent8:
            metalPixelFormat = .r8Unorm
            
        default:
            throw MetalHelperError.unsupportedPixelBufferFormat(
                "Unsupported CVPixelBuffer format: \(cvPixelFormat)"
            )
        }
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            metalPixelFormat,
            width,
            height,
            0,
            &cvTexture
        )
        
        guard status == kCVReturnSuccess, let cvTexture else {
            return nil
        }
        
        return CVMetalTextureGetTexture(cvTexture)
    }
    
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
    
    static func getPixels(from texture: MTLTexture) -> [SIMD4<Float>] {
        let width = texture.width
        let height = texture.height
        let pixelCount = width * height
        
        switch texture.pixelFormat {
            
        case .rgba32Float:
            let bytesPerRow = width * 16
            var raw = [Float](repeating: 0, count: pixelCount * 4)
            texture.getBytes(&raw, bytesPerRow: bytesPerRow,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return stride(from: 0, to: raw.count, by: 4).map {
                SIMD4<Float>(raw[$0], raw[$0+1], raw[$0+2], raw[$0+3])
            }
            
        case .bgra8Unorm, .bgra8Unorm_srgb:
            let bytesPerRow = width * 4
            var raw = [UInt8](repeating: 0, count: pixelCount * 4)
            texture.getBytes(&raw, bytesPerRow: bytesPerRow,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return stride(from: 0, to: raw.count, by: 4).map {
                // bgra order → remap to xyzw = rgba
                SIMD4<Float>(
                    Float(raw[$0+2]) / 255.0,  // R
                    Float(raw[$0+1]) / 255.0,  // G
                    Float(raw[$0])   / 255.0,  // B
                    Float(raw[$0+3]) / 255.0   // A
                )
            }
            
        case .rgba8Unorm, .rgba8Unorm_srgb:
            let bytesPerRow = width * 4
            var raw = [UInt8](repeating: 0, count: pixelCount * 4)
            texture.getBytes(&raw, bytesPerRow: bytesPerRow,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            return stride(from: 0, to: raw.count, by: 4).map {
                SIMD4<Float>(
                    Float(raw[$0])   / 255.0,
                    Float(raw[$0+1]) / 255.0,
                    Float(raw[$0+2]) / 255.0,
                    Float(raw[$0+3]) / 255.0
                )
            }
            
        default:
            assertionFailure("getPixels: unhandled pixel format \(texture.pixelFormat.rawValue)")
            return []
        }
    }
    
    /**
     * Not using bug gonna keep, issue is that if we're in dark mode or light mode,
     * processing the "color" gets weird results
     */
    public static func getColors(from texture: MTLTexture) -> [Color] {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        
        texture.getBytes(
            &pixels,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(origin: .init(x: 0, y: 0, z: 0),
                            size: .init(width: width, height: height, depth: 1)),
            mipmapLevel: 0
        )
        
        return stride(from: 0, to: pixels.count, by: 4).map { i in
            Color(
                .sRGB,
                red:     Double(pixels[i])     / 255,
                green:   Double(pixels[i + 1]) / 255,
                blue:    Double(pixels[i + 2]) / 255,
                opacity: Double(pixels[i + 3]) / 255
            )
        }
    }
}
