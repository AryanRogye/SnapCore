//
//  Blending.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/23/26.
//

import Metal

struct BlendingUniform: MetalUniform {}

public final class Blending: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoBlending: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!

    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "alphaBlendTextures")
        
        do {
            psoBlending = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create blending pipeline state: \(error)")
        }
    }
    
    /// Alpha-composites `image` over `base` using `image.a` as a straight-alpha mask.
    public func blend(
        base: MTLTexture,
        image: MTLTexture,
    ) -> MTLTexture? {
        guard let pso = psoBlending,
              let out = makeOutputTexture(matching: base) else { return nil }
        
        
        var uniforms = BlendingUniform()
        return dispatch(
            pso: pso,
            input: base,
            output: out,
            uniforms: &uniforms
        ) { enc in
            enc.setTexture(base, index: 0)
            enc.setTexture(image, index: 1)
            enc.setTexture(out, index: 2)
        }
    }
}
