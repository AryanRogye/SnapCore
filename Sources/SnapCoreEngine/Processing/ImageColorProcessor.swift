//
//  ImageColorProcessor.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#if os(macOS)
import Accelerate
import AppKit

final class ImageColorProcessor {
    
    public func getDominantColor(from image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return getDominantColor(from: cgImage)
    }
    
    /**
     * Extracts the dominant color from an image for UI theming.
     * Ensures minimum brightness for visibility.
     * - Parameter image: The NSImage to analyze.
     * - Returns: The dominant NSColor, or nil if extraction fails.
     */
    public func getDominantColor(from cgImage: CGImage) -> NSColor? {
        // Use vImage for fast resizing (part of Accelerate framework)
        let targetSize = CGSize(width: 1, height: 1)
        
        guard let resized = resizeImageWithVImage(cgImage, to: targetSize) else {
            return nil
        }
        
        // Direct pixel access - much faster than CGContext
        guard let pixelData = resized.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixelData) else {
            return nil
        }
        
        // Extract RGBA values (assuming RGBA format)
        let red = CGFloat(bytes[0]) / 255.0
        let green = CGFloat(bytes[1]) / 255.0
        let blue = CGFloat(bytes[2]) / 255.0
        let alpha = CGFloat(bytes[3]) / 255.0
        
        // Apply brightness adjustment
        return adjustBrightness(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /**
     * Ultra-fast image resizing using vImage (Accelerate framework)
     */
    private func resizeImageWithVImage(_ cgImage: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Define the format
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB()),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )
        
        // Source buffer
        var sourceBuffer = vImage_Buffer()
        var destBuffer = vImage_Buffer()
        
        // Init source buffer
        guard vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags)) == kvImageNoError else {
            return nil
        }
        
        destBuffer.width = vImagePixelCount(width)
        destBuffer.height = vImagePixelCount(height)
        destBuffer.rowBytes = width * 4
        destBuffer.data = malloc(height * width * 4)
        
        // Resize
        let error = vImageScale_ARGB8888(&sourceBuffer, &destBuffer, nil, vImage_Flags(kvImageHighQualityResampling))
        
        free(sourceBuffer.data)
        
        guard error == kvImageNoError else {
            free(destBuffer.data)
            return nil
        }
        
        // Make image
        let context = CGContext(
            data: destBuffer.data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: destBuffer.rowBytes,
            space: format.colorSpace.takeRetainedValue(),
            bitmapInfo: format.bitmapInfo.rawValue
        )
        
        let result = context?.makeImage()
        free(destBuffer.data)
        return result
    }
}


extension ImageColorProcessor {
    internal func adjustBrightness(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat
    ) -> NSColor {
        var adjustedRed = red
        var adjustedGreen = green
        var adjustedBlue = blue
        
        let brightness = (red + green + blue) / 3.0
        
        if brightness < 0.5 { // 128/255 ≈ 0.5
            let scale = 0.5 / brightness
            adjustedRed = min(red * scale, 1.0)
            adjustedGreen = min(green * scale, 1.0)
            adjustedBlue = min(blue * scale, 1.0)
        }
        
        return NSColor(red: adjustedRed, green: adjustedGreen, blue: adjustedBlue, alpha: alpha)
    }
}
#endif
