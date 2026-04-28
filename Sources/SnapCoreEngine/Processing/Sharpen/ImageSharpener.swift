//
//  ImageSharpener.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Metal
import MetalKit
import Foundation
import CoreImage

private struct SharpenUniforms: MetalUniform {
    var sharpness: Float
    var radius: Int32
    var detail: Float
}

public final class ImageSharpener: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoSharpen: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "sharpen_kernel")
        
        do {
            psoSharpen = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create sharpening pipeline state: \(error)")
        }
    }

    public func sharpen(
        _ image: MTLTexture,
        sharpness: Float = 0.0,
        radius: Int = 1,
        detail: Float = 0.1,
    ) throws -> MTLTexture? {
        
        guard let pso = psoSharpen,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = SharpenUniforms(
            sharpness: sharpness,
            radius: Int32(radius),
            detail: detail
        )
        
        return dispatch(
            pso: pso,
            input: image,
            output: out,
            uniforms: &uniforms
        ) { enc in
            enc.setTexture(image, index: 0)
            enc.setTexture(out, index: 1)
        }
    }
}
