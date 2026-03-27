//
//  LanczosUpscalerTests.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//


import XCTest
import Metal
@testable import SnapCoreEngine

class LanczosUpscalerTests: XCTestCase {
    var upscaler: LanczosUpscaler!
    var device: MTLDevice!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()!
        upscaler = LanczosUpscaler()
    }
    
    // MARK: - Basic Sanity
    
    func test_outputSize_isScaled() {
        let input = makeSolidTexture(width: 100, height: 100, color: .init(1, 0, 0, 1))
        let output = upscaler.upscale(input, lanczosScale: 2.0, kernelSize: 3)!
        
        XCTAssertEqual(output.width, 200)
        XCTAssertEqual(output.height, 200)
    }
    
    func test_solidRed_remainsRed() {
        // A solid color upscaled should still be solid color
        let input = makeSolidTexture(width: 50, height: 50, color: .init(1, 0, 0, 1))
        let output = upscaler.upscale(input, lanczosScale: 2.0, kernelSize: 3)!
        
        let pixels = readPixels(output)
        let center = pixels[output.width * (output.height / 2) + output.width / 2]
        
        XCTAssertEqual(center.r, 255, accuracy: 2)
        XCTAssertEqual(center.g, 0,   accuracy: 2)
        XCTAssertEqual(center.b, 0,   accuracy: 2)
    }
    
    func test_scaleOne_isPassthrough() {
        let input = makeGradientTexture(width: 64, height: 64)
        let output = upscaler.upscale(input, lanczosScale: 1.0, kernelSize: 3)!
        
        XCTAssertEqual(output.width, input.width)
        XCTAssertEqual(output.height, input.height)
        
        let inPx  = readPixels(input)
        let outPx = readPixels(output)
        
        // Center pixels should be nearly identical at 1x
        let i = inPx.count / 2
        XCTAssertEqual(inPx[i].r, outPx[i].r, accuracy: 3)
        XCTAssertEqual(inPx[i].g, outPx[i].g, accuracy: 3)
    }
    
    func test_maxScaleDoesntCrash() {
        let input = makeSolidTexture(width: 100, height: 100, color: .init(0, 1, 0, 1))
        // Should clamp to 16384 not crash
        let output = upscaler.upscale(input, lanczosScale: 200.0, kernelSize: 3)
        XCTAssertNotNil(output)
        XCTAssertLessThanOrEqual(output!.width, 16384)
    }
    
    func test_zeroScaleDoesntCrash() {
        let input = makeSolidTexture(width: 100, height: 100, color: .init(0, 1, 0, 1))
        let output = upscaler.upscale(input, lanczosScale: 0.0, kernelSize: 3)
        XCTAssertNotNil(output)
        XCTAssertGreaterThanOrEqual(output!.width, 1)
    }
    
    func test_impulseProducesLanczosShape() {
        let input = makeImpulseTexture(width: 9, height: 9)
        let output = upscaler.upscale(input, lanczosScale: 4.0, kernelSize: 3)!
        
        let pixels = readPixels(output)
        
        let centerIndex = (output.height / 2) * output.width + (output.width / 2)
        let center = pixels[centerIndex]
        
        // center should still be strongest
        XCTAssertGreaterThan(center.r, 200)
        
        // nearby pixels should NOT be zero (this proves filtering happened)
        let neighbor = pixels[centerIndex + 1]
        XCTAssertGreaterThan(neighbor.r, 0)
    }
    
    func test_singleWhitePixel_spreadsCorrectly() {
        // Create a 5x5 texture (center white pixel is at x:2, y:2)
        let input = makeBlackWithWhitePixelTexture(width: 5, height: 5)
        
        // Upscale 3x to 15x15
        let output = upscaler.upscale(input, lanczosScale: 3.0, kernelSize: 3)!
        
        XCTAssertEqual(output.width, 15)
        XCTAssertEqual(output.height, 15)
        
        let outPx = readPixels(output)
        
        // Check center pixel (7,7) - should retain most of the brightness
        let center = outPx[7 * output.width + 7]
        XCTAssertGreaterThan(center.r, 100, "Center should remain bright")
        
        // Check a corner pixel (0,0) - should be unaffected by the kernel and stay black
        let corner = outPx[0]
        XCTAssertLessThan(corner.r, 5, "Corners should stay dark")
    }
    
    // MARK: - Helpers
    
    struct RGBA { var r, g, b, a: UInt8 }
    
    func readPixels(_ tex: MTLTexture) -> [RGBA] {
        // Blit private → shared so CPU can read it
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: tex.pixelFormat,
            width: tex.width, height: tex.height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        
        let device = MTLCreateSystemDefaultDevice()!
        let staging = device.makeTexture(descriptor: desc)!
        
        let queue = device.makeCommandQueue()!
        let cmd = queue.makeCommandBuffer()!
        let blit = cmd.makeBlitCommandEncoder()!
        blit.copy(from: tex, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: tex.width, height: tex.height, depth: 1),
                  to: staging, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        
        var bytes = [UInt8](repeating: 0, count: tex.width * tex.height * 4)
        staging.getBytes(&bytes, bytesPerRow: tex.width * 4,
                         from: MTLRegionMake2D(0, 0, tex.width, tex.height),
                         mipmapLevel: 0)
        
        return stride(from: 0, to: bytes.count, by: 4).map {
            RGBA(r: bytes[$0], g: bytes[$0+1], b: bytes[$0+2], a: bytes[$0+3])
        }
    }
    
    func makeSolidTexture(width: Int, height: Int, color: SIMD4<Float>) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        let tex = device.makeTexture(descriptor: desc)!
        let pixel: [UInt8] = [
            UInt8(color.x * 255), UInt8(color.y * 255),
            UInt8(color.z * 255), UInt8(color.w * 255)
        ]
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = pixel[0]; bytes[i+1] = pixel[1]
            bytes[i+2] = pixel[2]; bytes[i+3] = pixel[3]
        }
        tex.replace(region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return tex
    }
    
    func makeGradientTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        let tex = device.makeTexture(descriptor: desc)!
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i]   = UInt8(x * 255 / width)
                bytes[i+1] = UInt8(y * 255 / height)
                bytes[i+2] = 128
                bytes[i+3] = 255
            }
        }
        tex.replace(region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return tex
    }
    
    func makeImpulseTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        
        let tex = device.makeTexture(descriptor: desc)!
        
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        
        let cx = width / 2
        let cy = height / 2
        let i = (cy * width + cx) * 4
        
        bytes[i]   = 255 // R
        bytes[i+1] = 255 // G
        bytes[i+2] = 255 // B
        bytes[i+3] = 255 // A
        
        tex.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: bytes,
            bytesPerRow: width * 4
        )
        
        return tex
    }
    
    func makeBlackWithWhitePixelTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        let tex = device.makeTexture(descriptor: desc)!
        
        // Initialize all to black (0, 0, 0, 0)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        
        // Set alpha to 255 for all pixels so it's opaque black
        for i in stride(from: 3, to: bytes.count, by: 4) {
            bytes[i] = 255
        }
        
        // Find the center pixel
        let centerX = width / 2
        let centerY = height / 2
        let centerIndex = (centerY * width + centerX) * 4
        
        // Make it white (255, 255, 255)
        bytes[centerIndex] = 255
        bytes[centerIndex + 1] = 255
        bytes[centerIndex + 2] = 255
        
        tex.replace(region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return tex
    }
}
