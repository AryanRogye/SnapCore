//
//  MetalContext.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Foundation
import Metal

final class MetalContext {
    
    static let shared = MetalContext()
    let device: MTLDevice
    let queue: MTLCommandQueue
    let library: MTLLibrary
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is unavailable on this system.")
        }
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create a Metal command queue.")
        }
        
        self.device = device
        self.queue = queue
        self.library = Self.makeLibrary(device: device)
    }

    private static func makeLibrary(device: MTLDevice) -> MTLLibrary {
        if let bundledLibrary = try? device.makeDefaultLibrary(bundle: .module) {
            return bundledLibrary
        }

        let shaderPaths = [
            ("Contrast", "metal", "Playback/Image/Contrast"),
            ("sharpen", "metal", "Playback/Image/Sharpen")
        ]
        
        let source = shaderPaths.map { name, ext, subdirectory in
            let url = Bundle.module.url(
                forResource: name,
                withExtension: ext,
                subdirectory: subdirectory
            ) ?? Bundle.module.url(
                forResource: name,
                withExtension: ext
            )
            
            guard let url else {
                fatalError("Missing Metal shader resource: \(subdirectory)/\(name).\(ext)")
            }
            
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                fatalError("Failed to load Metal shader resource \(name).\(ext): \(error)")
            }
        }.joined(separator: "\n")
        
        do {
            return try device.makeLibrary(source: source, options: nil)
        } catch {
            fatalError("Failed to compile bundled Metal shaders: \(error)")
        }
    }
}
