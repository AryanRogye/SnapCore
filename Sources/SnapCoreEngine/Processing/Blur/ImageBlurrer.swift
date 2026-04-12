//
//  ImageBlurrer.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/11/26.
//

import Metal
import MetalKit
import Foundation
import CoreImage

struct BlurUniform: MetalUniform {
    var radius: Int32
    var detail: Float
}

final class ImageBlurrer: MetalFilter {
    let ctx : MetalContext = .shared
    
    private var psoBlur: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "apply_blur")
        
        do {
            psoBlur = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create blur pipeline state: \(error)")
        }
    }
    
    public func applyBlur(
        for image: MTLTexture,
        radius: Int,
        detail: Float
    ) throws -> MTLTexture? {
        guard radius > 0 else { return nil }
        guard detail > 0 else { return nil }
        guard let pso = psoBlur,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        let sigma = 0.3 + Float(detail) * Float(radius) * 1.5
        var uniforms = BlurUniform(
            radius: Int32(radius),
            detail: sigma
        )
        
        print("Applying Blur: Radius: \(uniforms.radius) Detail: \(uniforms.detail)")
        
        return dispatch(pso: pso, input: image, output: out, uniforms: &uniforms) { enc in
            enc.setTexture(image, index: 0)
            enc.setTexture(out, index: 1)
        }
    }
}
