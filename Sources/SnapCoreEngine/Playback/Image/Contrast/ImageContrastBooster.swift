//
//  ImageContrastBooster.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Metal
import MetalKit
import Foundation
import CoreImage

struct ContrastUniforms {
    var factor: Float
}

class ImageContrastBooster {
    
    let ctx : MetalContext = .shared
    
    private var psoContrast: MTLComputePipelineState!
    private var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "adjustContrast")
        
        do {
            psoContrast = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create contrast pipeline state: \(error)")
        }
    }

    public func boostContrast(
        for image: CGImage,
        factor: Float
    ) throws -> CGImage? {
        let texture = try MetalHelpers.getImageTexture(from: image)
        
        let width = image.width
        let height = image.height
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, // Standard 8-bit color
            width: width,
            height: height,
            mipmapped: false
        )
        
        // Crucial: Tell Metal this texture is for writing results
        descriptor.usage = [.shaderWrite, .shaderRead]
        
        guard let outTexture = ctx.device.makeTexture(
            descriptor: descriptor) else {
            return nil
        }
        
        guard let pso = psoContrast,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            return nil
        }
        
        enc.setComputePipelineState(pso)
        // Index 0 is our input (read)
        enc.setTexture(texture, index: 0)
        
        // Index 1 is our output (write)
        enc.setTexture(outTexture, index: 1)
        
        var uniforms = ContrastUniforms(factor: factor)
        enc.setBytes(&uniforms, length: MemoryLayout<ContrastUniforms>.stride, index: 0)
        
        let w = pso.threadExecutionWidth
        let h = pso.maxTotalThreadsPerThreadgroup / w
        let threadgroupSize = MTLSize(width: w, height: h, depth: 1)
        let gridSize = MTLSize(width: image.width, height: image.height, depth: 1)
        enc.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        enc.endEncoding()
        
        cmd.commit()
        cmd.waitUntilCompleted()
        
        guard let ciImage = CIImage(mtlTexture: outTexture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        
        let context = CIContext(mtlDevice: ctx.device)
        return context.createCGImage(flipped, from: flipped.extent)
    }
}
