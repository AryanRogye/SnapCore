//
//  ImageSaturationAdjuster.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/23/26.
//

import Metal
import MetalKit

private struct SaturationUniforms: MetalUniform {
    var factor: Float
}

public final class ImageSaturationAdjuster: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoSaturation: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        let function = ctx.library.makeFunction(name: "adjust_saturation")
        
        do {
            psoSaturation = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create saturation pipeline state: \(error)")
        }
    }
    
    public func adjustSaturation(
        for image: MTLTexture,
        factor: Float
    ) throws -> MTLTexture? {
        guard let pso = psoSaturation,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = SaturationUniforms(factor: factor)
        
        return dispatch(pso: pso, input: image, output: out, uniforms: &uniforms) { enc in
            enc.setTexture(image, index: 0)
            enc.setTexture(out, index: 1)
        }
    }
}
