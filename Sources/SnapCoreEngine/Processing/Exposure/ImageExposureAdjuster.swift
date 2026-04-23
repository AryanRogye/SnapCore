//
//  ImageExposureAdjuster.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/11/26.
//

import Metal
import MetalKit
import Foundation
import CoreImage

private struct ExposureUniforms: MetalUniform {
    var factor: Float
}

public class ImageExposureAdjuster: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoExposure: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "apply_exposure")
        
        do {
            psoExposure = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create exposure pipeline state: \(error)")
        }
    }
    
    public func adjustExposure(
        for image: MTLTexture,
        factor: Float
    ) throws -> MTLTexture? {
        guard let pso = psoExposure,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = ExposureUniforms(factor: factor)
        
        return dispatch(pso: pso, input: image, output: out, uniforms: &uniforms) { enc in
            enc.setTexture(image, index: 0)
            enc.setTexture(out, index: 1)
        }
    }
}
