//
//  CursorSticher.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import Metal
import MetalKit
import Foundation
import CoreImage

private struct MousePosition {
    var x : Float
    var y : Float
    var hotspotX: Float;
    var hotspotY: Float;
}

/// Function takes a base image and a cursor texture
/// and stiches it onto it
public final class CursorSticher {
    
    let ctx : MetalContext = .shared
    
    private var psoCursor: MTLComputePipelineState!
    private var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "stitchCursor")
        do {
            psoCursor = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create sharpening pipeline state: \(error)")
        }
    }
    
    public func apply(
        _ cursor: MTLTexture,
        onto image: MTLTexture,
        at point: CGPoint,
        screen: CGRect
    ) throws -> MTLTexture? {
        
        let width = image.width
        let height = image.height
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, // Standard 8-bit color
            width: width,
            height: height,
            mipmapped: false
        )
        
        descriptor.usage = [.shaderWrite, .shaderRead]
        
        guard let outTexture = ctx.device.makeTexture(
            descriptor: descriptor) else {
            return nil
        }
        
        guard let pso = psoCursor,
              let cmd = queue.makeCommandBuffer(),
              let enc = cmd.makeComputeCommandEncoder() else {
            return nil
        }
        
        let scaleX = CGFloat(image.width) / screen.width
        let scaleY = CGFloat(image.height) / screen.height
        
        let mappedPoint = CGPoint(
            x: (point.x - screen.minX) * scaleX,
            y: (point.y - screen.minY) * scaleY
        )
        
        enc.setComputePipelineState(pso)
        // Index 0 is our image texture input (read)
        enc.setTexture(image, index: 0)
        // Index 1 is our cursor texture (read)
        enc.setTexture(cursor, index: 1)
        // Index 2 is our outTexture
        enc.setTexture(outTexture, index: 2)
        
        var uniforms = MousePosition(
            x: Float(mappedPoint.x),
            y: Float(mappedPoint.y),
            hotspotX: Float(cursor.width) * 0.28,
            hotspotY: Float(cursor.height) * 0.08
        )
        enc.setBytes(
            &uniforms,
            length: MemoryLayout<MousePosition>.stride,
            index: 0
        )
        
        let w = pso.threadExecutionWidth
        let h = pso.maxTotalThreadsPerThreadgroup / w
        let threadgroupSize = MTLSize(width: w, height: h, depth: 1)
        let gridSize = MTLSize(width: image.width, height: image.height, depth: 1)
        enc.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
        enc.endEncoding()
        
        cmd.commit()
        cmd.waitUntilCompleted()

        return outTexture
    }
}
