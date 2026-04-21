//
//  IlluminanceDetection.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/20/26.
//

import Metal
import SwiftUI

private struct IlluminanceDetectionUniforms: MetalUniform {
    var brightnessThreshold: Float
    var contrastControl: Float
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
            brightnessThreshold: threshold,
            contrastControl: preProcess(texture: image)
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
    
    /**
     * https://pages.cs.wisc.edu/~lizhang/courses/cs766-2012f/projects/hdr/Reinhard2005DRR.pdf
     * Function Retreives a Lmax Lav, and Lmin given by:
     * k = (Lmax − Lav)/(Lmax − Lmin)
     * This function will use a difference luminance than the metal shader
     * current metal shader uses 0.2126, 0.7152, 0.0722
     * but we will use 0.2125, 0.7154, 0.0721
     * This should give us the m = 0.3 + 0.7k^1.4.
     */
    private func preProcess(texture: MTLTexture) -> Float {
        
        let pixels = MetalHelpers.getPixels(from: texture)
        
        var Lmax: Float = -.greatestFiniteMagnitude
        var Lmin: Float = .greatestFiniteMagnitude
        var sumLog: Float = 0
        let epsilon: Float = 0.0001
        
        for pixel in pixels {
            
            let L = getLuminance(from: pixel)
            /// get the max value
            if L > Lmax {
                Lmax = L
            }
            /// get the min value
            if L < Lmin {
                Lmin = L
            }
            
            sumLog += log(epsilon + L)
        }
        
        let Lav = exp(sumLog / Float(pixels.count))
        
        let denom = Lmax - Lmin
        guard denom > 0 else { return 0.3 }
        
        let k = (Lmax - Lav) / denom
        return 0.3 + (0.7 * pow(k, 1.4))
    }
    
    internal func getLuminance(from pixel: SIMD4<Float>) -> Float {
        return (0.2125 * pixel.x) + (0.7154 * pixel.y) + (0.0721 * pixel.z)
    }
}
