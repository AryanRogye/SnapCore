//
//  MetalImageView.swift
//  CameraTest
//
//  Created by Aryan Rogye on 4/19/26.
//


import UIKit
import Metal
import MetalKit
import SwiftUI
import Combine
import SnapCoreEngine

struct Viewport {
    /// Represents the origin we start at
    var origin: SIMD2<Float> = .zero
    /// 1.0 - 100% Scale
    var scale: Float = 1.0
    /// Updated from the MTKView drawable size before each frame.
    var viewAspect: Float = 1.0
}

struct Vertex {
    var pos: SIMD2<Float>
}



struct MetalImageView: UIViewRepresentable {
    
    @Binding var viewport: Viewport
    var texture: MTLTexture?
    
    init(
        viewport: Binding<Viewport>,
        texture: MTLTexture?
    ) {
        self._viewport = viewport
        self.texture = texture
    }
    
    
    private let ctx = MetalContext.shared
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = ctx.device
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.autoResizeDrawable = true
        mtkView.framebufferOnly = true
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 120
        context.coordinator.viewport = viewport
        
        if let texture {
            context.coordinator.setImageTexture(texture)
        }
        
        return mtkView
    }
    
    func updateUIView(_ nsView: MTKView, context: Context) {
        // push viewport every time (uniform update)
        context.coordinator.viewport = viewport
        
        if let texture {
            context.coordinator.setImageTexture(texture)
        }
        
        // request a redraw (needed for both new texture and viewport changes)
        nsView.setNeedsDisplay(nsView.bounds)
        nsView.draw()
    }
    
    class Coordinator : NSObject, MTKViewDelegate {
        private var device: MTLDevice!
        private var queue: MTLCommandQueue!
        private var pso: MTLRenderPipelineState!
        
        private var vertexBuffer   : MTLBuffer!
        private var viewportBuffer : MTLBuffer!
        
        /// Textures
        private var imageTexture   : MTLTexture!
        
        public var viewport: Viewport?
        
        /// Parent
        var parent: MetalImageView
        
        /// Verticies Of The Thing we're gonna show it on
        let verts: [Vertex] = [
            /// Bottom Left
            .init(pos: [-1, -1]),
            /// Top Left
            .init(pos: [-1, 1]),
            /// Top Right
            .init(pos: [1, 1]),
            
            /// Bottom Left
            .init(pos: [-1, -1]),
            /// Bottom Right
            .init(pos: [1, -1]),
            /// Top Right
            .init(pos: [1, 1])
        ]
        
        private weak var currentView: MTKView?
        private var cancellables: Set<AnyCancellable> = []
        
        init(_ parent: MetalImageView) {
            self.parent = parent
            super.init()
            
            setupMetal()
        }
        
        /// Function to setup the buffers at the start, this is nice for the vertex and the viewport
        private func setupMetal() {
            device = parent.ctx.device
            queue = parent.ctx.queue
            guard let lib = device.makeDefaultLibrary() else {
                fatalError("Could not load default Metal library")
            }
            
            let desc = MTLRenderPipelineDescriptor()
            let vertFn = lib.makeFunction(name: "vertexImageShader")
            let fragFn = lib.makeFunction(name: "fragmentImageShader")
            desc.vertexFunction = vertFn
            desc.fragmentFunction = fragFn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            pso = try! device.makeRenderPipelineState(descriptor: desc)
            
            vertexBuffer = device.makeBuffer(
                bytes: verts,
                length: MemoryLayout<Vertex>.stride * verts.count
            )
            
            viewportBuffer = device.makeBuffer(
                length: MemoryLayout<Viewport>.stride,
                options: []
            )
        }
        
        // MARK: - Main Draw
        func draw(in view: MTKView) {
            guard let rpd = view.currentRenderPassDescriptor,
                  let drw = view.currentDrawable,
                  let imageTexture,
                  view.drawableSize.height > 0 else { return }
            currentView = view
            
            let viewport = viewport ?? Viewport()
            let viewportBufferInfo = viewportBuffer.contents().bindMemory(
                to: Viewport.self,
                capacity: 1
            )
            viewportBufferInfo.pointee = Viewport(
                origin: viewport.origin,
                scale: viewport.scale,
                viewAspect: Float(view.drawableSize.width / view.drawableSize.height)
            )
            
            let cmd = queue.makeCommandBuffer()!
            let enc = cmd.makeRenderCommandEncoder(descriptor: rpd)!
            
            enc.setRenderPipelineState(pso)
            enc.setVertexBuffer(
                vertexBuffer,
                offset: 0,
                index: 0
            )
            enc.setVertexBuffer(
                viewportBuffer,
                offset: 0,
                index: 1
            )
            
            enc.setFragmentTexture(imageTexture, index: 0)
            
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            enc.endEncoding()
            cmd.present(drw)
            
            
            // Add completion handler to measure GPU time
            cmd.addCompletedHandler { [weak self] cb in
                
                /// true GPU timing
                if cb.gpuStartTime > 0, cb.gpuEndTime > 0 {
                    let ms = (cb.gpuEndTime - cb.gpuStartTime) * 1000.0
                    DispatchQueue.main.async {
//                        self?.parent.comfyMarkVM.onLastRenderTime(ms)
                    }
                }
            }
            cmd.commit()
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        // MARK: - Setters For Textures
        
        public func setImageTexture(_ texture: MTLTexture) {
            self.imageTexture = texture
        }
    }
}
