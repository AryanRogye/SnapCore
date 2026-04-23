//
//  MetalFilter.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

import MetalKit

protocol MetalFilter: AnyObject {
    var ctx: MetalContext { get }
    var queue: MTLCommandQueue! { get }
}

protocol MetalUniform {}

extension MetalFilter {
    
    func makeOutputTexture(scale: Float = 1.0, matching input: MTLTexture) -> MTLTexture? {
        let maxSize = ctx.device.supportsFamily(.apple3) ? 16384 : 8192
        
        let width  = max(1, min(Int(Float(input.width)  * scale), maxSize))
        let height = max(1, min(Int(Float(input.height) * scale), maxSize))
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: input.pixelFormat,
            width:  width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderWrite, .shaderRead]
        descriptor.storageMode = .private
        return ctx.device.makeTexture(descriptor: descriptor)
    }

    func dispatch<U: MetalUniform>(
        pso: MTLComputePipelineState,
        input: MTLTexture,
        output: MTLTexture,
        uniforms: inout U,
        setup: (MTLComputeCommandEncoder) -> Void
    ) -> MTLTexture? {
        guard let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else { return nil }
        
        enc.setComputePipelineState(pso)
        withUnsafeBytes(of: &uniforms) { bytes in
            guard bytes.count > 0, let baseAddress = bytes.baseAddress else { return }
            enc.setBytes(baseAddress, length: bytes.count, index: 0)
        }
        setup(enc)
        
        let w = pso.threadExecutionWidth
        let h = pso.maxTotalThreadsPerThreadgroup / w
        enc.dispatchThreads(
            MTLSize(width: output.width, height: output.height, depth: 1),
            threadsPerThreadgroup: MTLSize(width: w, height: h, depth: 1)
        )
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
        
        return output
    }
}
