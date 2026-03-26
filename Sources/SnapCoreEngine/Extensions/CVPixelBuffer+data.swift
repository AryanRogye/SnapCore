//
//  CVPixelBuffer+data.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/26/26.
//

import Foundation
import AVFoundation

extension CVPixelBuffer {
    func data() -> Data? {
        let pixelBuffer = self
        // 1. Lock the base address
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0)) // rawValue 0 means read/write access
        
        defer {
            // 4. Ensure the base address is unlocked when the function returns
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        // 2. Get pixel information
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let totalBytes = bytesPerRow * height
        
        // 3. Create the Data object from the raw bytes
        // The `Data` object will create a copy of the pixel buffer's memory
        let pixelData = Data(bytes: baseAddress, count: totalBytes)
        
        return pixelData
    }
}
