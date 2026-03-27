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
    
    var cursorShadowX: Float;
    var cursorShadowY: Float;
    var cursorShadowOpacity: Float;
    
    var cursorShadowSharpX: Float
    var cursorShadowSharpY: Float
    var cursorShadowSharpOpacity: Float
    
    var currentAngle: Float
    var dx: Float
    var dy: Float
}

/// observable so we can view it nice in the ui
@Observable
public class CursorShadowConfig {
    // outter shadow
    public var cursorShadowX: CGFloat = 3.0;
    public var cursorShadowY: CGFloat = 3.0;
    public var cursorShadowOpacity: CGFloat = 0.35;
    
    // tight inner shadow
    public var cursorShadowSharpX: CGFloat = 1.0
    public var cursorShadowSharpY: CGFloat = 2.0
    public var cursorShadowSharpOpacity: CGFloat = 0.30
    
    public init() {
        
    }
}

/// Function takes a base image and a cursor texture
/// and stiches it onto it
public final class CursorSticher: MetalFilter {
    
    let ctx : MetalContext = .shared
    
    private var psoCursor: MTLComputePipelineState!
    internal var queue: MTLCommandQueue!
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
        screen: CGRect,
        shadowConfig: CursorShadowConfig,
        cursorMotionState: CursorMotionState
    ) throws -> MTLTexture? {
        guard let pso = psoCursor,
              let out = makeOutputTexture(matching: image) else { return nil }
        
        let scaleX = CGFloat(image.width) / screen.width
        let scaleY = CGFloat(image.height) / screen.height
        let mappedPoint = CGPoint(
            x: (point.x - screen.minX) * scaleX,
            y: (point.y - screen.minY) * scaleY
        )
        
        var uniforms = MousePosition(
            x: Float(mappedPoint.x),
            y: Float(mappedPoint.y),
            hotspotX: Float(cursor.width) * 0.28,
            hotspotY: Float(cursor.height) * 0.08,
            cursorShadowX: Float(shadowConfig.cursorShadowX),
            cursorShadowY: Float(shadowConfig.cursorShadowY),
            cursorShadowOpacity: Float(shadowConfig.cursorShadowOpacity),
            cursorShadowSharpX: Float(shadowConfig.cursorShadowSharpX),
            cursorShadowSharpY: Float(shadowConfig.cursorShadowSharpY),
            cursorShadowSharpOpacity: Float(shadowConfig.cursorShadowSharpOpacity),
            currentAngle: Float(cursorMotionState.currentAngle),
            dx: Float(cursorMotionState.dx),
            dy: Float(cursorMotionState.dy)
        )
        
        return dispatch(pso: pso, input: image, output: out, uniforms: &uniforms) { enc in
            enc.setTexture(image, index: 0)
            enc.setTexture(cursor, index: 1)
            enc.setTexture(out, index: 2)
        }
    }
}
