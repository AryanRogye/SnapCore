//
//  LanczosUpscaler.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

import Metal

private struct LanczosUniforms {
    var scale: Float
    var kernelSize: Int
}

final class LanczosUpscaler: MetalFilter {
    let ctx : MetalContext = .shared
    
    private var psolanczos: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
    private var uniformBuf: MTLBuffer!
    
    init() {
        self.queue = ctx.device.makeCommandQueue()
        
        // Load the shader function
        let function = ctx.library.makeFunction(name: "lanczos_upscale")
        
        do {
            psolanczos = try ctx.device.makeComputePipelineState(function: function!)
        } catch {
            print("Failed to create lanczos pipeline state: \(error)")
        }
    }
    
    public func upscale(
        _ image: MTLTexture,
        lanczosScale: Float,
        kernelSize: Int
    ) -> MTLTexture? {
        guard let pso = psolanczos,
              let out = makeOutputTexture(scale: lanczosScale, matching: image) else { return nil }
        
        var uniforms = LanczosUniforms(
            scale: lanczosScale,
            kernelSize: kernelSize
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




/// tbh didnt know if it was working so i needed this
#if DEBUG
import SwiftUI

#Preview {
    TestView()
}

struct TestView: View {
    
    @State private var left: CGImage?
    @State private var right: CGImage?
    @State var test = Test()
    
    @State private var scale: CGFloat = 1.0
    @State private var kernelSize: Int = 3
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let left {
                    Image(decorative: left, scale: 1)
                }
                Rectangle().frame(width: 2, height: 200)
                    .foregroundStyle(.white.opacity(0.1))
                if let right {
                    Image(decorative: right, scale: 1)
                }
            }
            
            Slider(value: $scale, in: 0.0...10.0)
                .padding()
            Slider(value: Binding(
                get: { Double(kernelSize) },
                set: { size in kernelSize = Int(size) }
            ), in: 0.0...10.0)
                .padding()
        }
        .frame(width: 402, height: 300, alignment: .top)
        .task {
            reload()
        }
        .onChange(of: scale) {
            reload()
        }
        .onChange(of: kernelSize) {
            reload()
        }
    }
    
    func reload() {
        let texture = test.makeBlackWithWhitePixelTexture(width: 9, height: 9)
        print("Texture Original: \(texture)")
        left = test.getCGImage(from: texture)
        
        if let modifiedTexture = test.upscaler.upscale(
            texture,
            lanczosScale: Float(scale),
            kernelSize: kernelSize
        ) {
            print("Modified Texture: \(modifiedTexture)")
            right = test.getCGImage(from: modifiedTexture)
        }
    }
}

@Observable
class Test {
    var upscaler: LanczosUpscaler!
    var device: MTLDevice!
    
    init() {
        device = MTLCreateSystemDefaultDevice()!
        upscaler = LanczosUpscaler()
    }
    
    private static let ciContext = CIContext(mtlDevice: MetalContext.shared.device)
    
    public func getCGImage(from texture: MTLTexture) -> CGImage? {
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        
        return Self.ciContext.createCGImage(flipped, from: flipped.extent)
    }
    
    func makeBlackWithWhitePixelTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        let tex = device.makeTexture(descriptor: desc)!
        
        // Initialize all to black (0, 0, 0, 0)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        
        // Set alpha to 255 for all pixels so it's opaque black
        for i in stride(from: 3, to: bytes.count, by: 4) {
            bytes[i] = 255
        }
        
        // Find the center pixel
        let centerX = width / 2
        let centerY = height / 2
        let centerIndex = (centerY * width + centerX) * 4
        
        // Make it white (255, 255, 255)
        bytes[centerIndex] = 255
        bytes[centerIndex + 1] = 255
        bytes[centerIndex + 2] = 255
        
        tex.replace(region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0, withBytes: bytes, bytesPerRow: width * 4)
        return tex
    }
}
#endif
