//
//  MetalContext.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import Foundation
import Metal

public final class MetalContext {
    
    public static let shared = MetalContext()
    public let device: MTLDevice
    public let queue: MTLCommandQueue
    public let library: MTLLibrary
    
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

        let sharedSource = loadShaderSource(
            name: "KernelNxN",
            ext: "metalh",
            subdirectory: "Processing"
        )

        let shaderPaths = [
            ("Contrast", "metal", "Processing/Contrast"),
            ("Sharpen", "metal", "Processing/Sharpen"),
            ("Cursor", "metal", "Processing/Cursor"),
            ("Lanczos", "metal", "Processing/Lanczos")
        ]
        
        let source = (
            [sharedSource] +
            shaderPaths.map { name, ext, subdirectory in
                loadShaderSource(name: name, ext: ext, subdirectory: subdirectory)
                    .replacingOccurrences(of: #"#include "../KernelNxN.metalh""#, with: "")
            }
        ).joined(separator: "\n")
        
        do {
            return try device.makeLibrary(source: source, options: nil)
        } catch {
            fatalError("Failed to compile bundled Metal shaders: \(error)")
        }
    }

    private static func loadShaderSource(
        name: String,
        ext: String,
        subdirectory: String
    ) -> String {
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
    }
}
