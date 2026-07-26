#if os(iOS)
import Metal
import MetalKit
import SwiftUI
import UIKit

/// A SwiftUI view that renders a Metal texture with aspect-fill scaling.
public struct MetalImageView: UIViewRepresentable {
    @Binding private var viewport: MetalImageViewport
    private let texture: MTLTexture?

    private let context = MetalContext.shared

    /// Creates a Metal-backed image view.
    ///
    /// - Parameters:
    ///   - viewport: The pan and zoom applied to the rendered texture.
    ///   - texture: The texture to render, or `nil` when no image is available.
    public init(
        viewport: Binding<MetalImageViewport>,
        texture: MTLTexture?
    ) {
        self._viewport = viewport
        self.texture = texture
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(context: context)
    }

    public func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = self.context.device
        view.delegate = context.coordinator
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.autoResizeDrawable = true
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 120

        context.coordinator.viewport = viewport
        context.coordinator.texture = texture
        return view
    }

    public func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.viewport = viewport
        context.coordinator.texture = texture
        view.draw()
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        fileprivate var viewport = MetalImageViewport()
        fileprivate var texture: MTLTexture?

        private let commandQueue: MTLCommandQueue
        private let pipelineState: MTLRenderPipelineState
        private let vertexBuffer: MTLBuffer
        private let viewportBuffer: MTLBuffer

        fileprivate init(context: MetalContext) {
            commandQueue = context.queue

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = context.library.makeFunction(
                name: "snapCoreMetalImageVertexShader"
            )
            descriptor.fragmentFunction = context.library.makeFunction(
                name: "snapCoreMetalImageFragmentShader"
            )
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            guard let pipelineState = try? context.device.makeRenderPipelineState(
                descriptor: descriptor
            ) else {
                fatalError("Failed to create the Metal image render pipeline.")
            }
            self.pipelineState = pipelineState

            let vertices: [Vertex] = [
                .init(position: [-1, -1]),
                .init(position: [-1, 1]),
                .init(position: [1, 1]),
                .init(position: [-1, -1]),
                .init(position: [1, -1]),
                .init(position: [1, 1]),
            ]

            guard let vertexBuffer = context.device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<Vertex>.stride * vertices.count
            ),
            let viewportBuffer = context.device.makeBuffer(
                length: MemoryLayout<ShaderViewport>.stride
            ) else {
                fatalError("Failed to create Metal image buffers.")
            }

            self.vertexBuffer = vertexBuffer
            self.viewportBuffer = viewportBuffer
            super.init()
        }

        public func draw(in view: MTKView) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let texture,
                  view.drawableSize.height > 0,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(
                      descriptor: renderPassDescriptor
                  ) else {
                return
            }

            viewportBuffer.contents()
                .bindMemory(to: ShaderViewport.self, capacity: 1)
                .pointee = ShaderViewport(
                    origin: viewport.origin,
                    scale: viewport.scale,
                    viewAspect: Float(view.drawableSize.width / view.drawableSize.height)
                )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(viewportBuffer, offset: 0, index: 1)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        public func mtkView(
            _ view: MTKView,
            drawableSizeWillChange size: CGSize
        ) {}
    }
}

private struct Vertex {
    var position: SIMD2<Float>
}

private struct ShaderViewport {
    var origin: SIMD2<Float>
    var scale: Float
    var viewAspect: Float
}
#elseif os(macOS)
import Metal
import MetalKit
import SwiftUI
import AppKit

/// A SwiftUI view that renders a Metal texture with aspect-fill scaling.
public struct MetalImageView: NSViewRepresentable {
    @Binding private var viewport: MetalImageViewport
    private let texture: MTLTexture?
    
    private let context = MetalContext.shared
    
    /// Creates a Metal-backed image view.
    ///
    /// - Parameters:
    ///   - viewport: The pan and zoom applied to the rendered texture.
    ///   - texture: The texture to render, or `nil` when no image is available.
    public init(
        viewport: Binding<MetalImageViewport>,
        texture: MTLTexture?
    ) {
        self._viewport = viewport
        self.texture = texture
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(context: context)
    }
    
    public func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = self.context.device
        view.delegate = context.coordinator
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.autoResizeDrawable = true
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 120
        // NSView-only: layer-backing isn't automatic like UIView.
        view.wantsLayer = true
        
        context.coordinator.viewport = viewport
        context.coordinator.texture = texture
        return view
    }
    
    public func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.viewport = viewport
        context.coordinator.texture = texture
        view.draw()
    }
    
    public final class Coordinator: NSObject, MTKViewDelegate {
        fileprivate var viewport = MetalImageViewport()
        fileprivate var texture: MTLTexture?
        
        private let commandQueue: MTLCommandQueue
        private let pipelineState: MTLRenderPipelineState
        private let vertexBuffer: MTLBuffer
        private let viewportBuffer: MTLBuffer
        
        fileprivate init(context: MetalContext) {
            commandQueue = context.queue
            
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = context.library.makeFunction(
                name: "snapCoreMetalImageVertexShader"
            )
            descriptor.fragmentFunction = context.library.makeFunction(
                name: "snapCoreMetalImageFragmentShader"
            )
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            guard let pipelineState = try? context.device.makeRenderPipelineState(
                descriptor: descriptor
            ) else {
                fatalError("Failed to create the Metal image render pipeline.")
            }
            self.pipelineState = pipelineState
            
            let vertices: [Vertex] = [
                .init(position: [-1, -1]),
                .init(position: [-1, 1]),
                .init(position: [1, 1]),
                .init(position: [-1, -1]),
                .init(position: [1, -1]),
                .init(position: [1, 1]),
            ]
            
            guard let vertexBuffer = context.device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<Vertex>.stride * vertices.count
            ),
                  let viewportBuffer = context.device.makeBuffer(
                    length: MemoryLayout<ShaderViewport>.stride
                  ) else {
                fatalError("Failed to create Metal image buffers.")
            }
            
            self.vertexBuffer = vertexBuffer
            self.viewportBuffer = viewportBuffer
            super.init()
        }
        
        public func draw(in view: MTKView) {
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let texture,
                  view.drawableSize.height > 0,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(
                    descriptor: renderPassDescriptor
                  ) else {
                return
            }
            
            viewportBuffer.contents()
                .bindMemory(to: ShaderViewport.self, capacity: 1)
                .pointee = ShaderViewport(
                    origin: viewport.origin,
                    scale: viewport.scale,
                    viewAspect: Float(view.drawableSize.width / view.drawableSize.height)
                )
            
            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(viewportBuffer, offset: 0, index: 1)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        public func mtkView(
            _ view: MTKView,
            drawableSizeWillChange size: CGSize
        ) {}
    }
}

private struct Vertex {
    var position: SIMD2<Float>
}

private struct ShaderViewport {
    var origin: SIMD2<Float>
    var scale: Float
    var viewAspect: Float
}

#endif
