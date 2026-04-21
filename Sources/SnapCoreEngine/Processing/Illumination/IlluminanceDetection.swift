//
//  IlluminanceDetection.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/20/26.
//

import Metal

private struct IlluminanceDetectionUniforms: MetalUniform {
    var brightnessThreshold: Float
}


public final class IlluminanceDetection: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoIlluminanceDetection: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "detect_illuminance")
        
        do {
            psoIlluminanceDetection = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create sharpening pipeline state: \(error)")
        }
    }
    
    public func detect_illuminance(
        in image: MTLTexture,
        threshold: Float
    ) -> MTLTexture? {
        guard let pso = psoIlluminanceDetection,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = IlluminanceDetectionUniforms(
            brightnessThreshold: threshold
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
