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

private struct IlluminanceDetectionAlternameUniforms: MetalUniform {
    var brightnessThreshold: Float
    var radius: Int32
}

private struct IlluminanceRecoveryUniforms: MetalUniform {
    var brightnessThreshold : Float
    var recovery: Float
    var showDebug: UInt32
}

public final class IlluminanceDetection: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoIlluminanceDetection: MTLComputePipelineState!
    private var psoIlluminanceDetectionAlternate: MTLComputePipelineState!
    private var psoRecovery: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    public init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "detect_illuminance")
        let function2 = ctx.library.makeFunction(name: "detect_illuminance_alternate")
        let function3 = ctx.library.makeFunction(name: "illuminance_recovery")
        
        do {
            psoIlluminanceDetection = try ctx.device.makeComputePipelineState(function: function!)
            psoIlluminanceDetectionAlternate = try ctx.device.makeComputePipelineState(function: function2!)
            psoRecovery = try ctx.device.makeComputePipelineState(function: function3!)
        } catch {
            print("Failed to create illuminance pipeline state: \(error)")
        }
    }
}

extension IlluminanceDetection {
    public func illuminance_recovery(
        in image: MTLTexture,
        threshold: Float,
        recovery: Float,
        showDebug: Bool,
    ) -> MTLTexture? {
        guard let pso = psoRecovery,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = IlluminanceRecoveryUniforms(
            brightnessThreshold: threshold,
            recovery: recovery,
            showDebug: showDebug ? 1 : 0
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

extension IlluminanceDetection {
    public func detect_illuminance_alternate(
        in image: MTLTexture,
        threshold: Float,
        radius: Int,
    ) -> MTLTexture? {
        guard let pso = psoIlluminanceDetectionAlternate,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        var uniforms = IlluminanceDetectionAlternameUniforms(
            brightnessThreshold: threshold,
            radius: Int32(radius)
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

extension IlluminanceDetection {
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
     * Implementing Dynamic Range Reduction inspired by Photoreceptor Physiology
     * by Erik Reinhard, Member, IEEE, and Kate Devlin
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
