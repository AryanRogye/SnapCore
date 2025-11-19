//
//  ScreenshotService+pixelCropRect.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import AppKit

extension ScreenshotService {
    /// Normalizes a requested crop rect into the coordinate space of an `NSScreen`.
    /// Values outside the screen bounds are clamped so ScreenCaptureKit can safely crop.
    static func normalizedCropRect(from rect: CGRect, on screen: NSScreen) -> CGRect {
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let r = rect.standardized
        
        let x = max(bounds.minX, min(r.minX, bounds.maxX))
        let y = max(bounds.minY, min(r.minY, bounds.maxY))
        
        let width = max(0, min(r.width, bounds.maxX - x))
        let height = max(0, min(r.height, bounds.maxY - y))
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

#endif
