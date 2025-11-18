//
//  ScreenshotService+pixelCropRect.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import AppKit

extension ScreenshotService {
    static func pixelCropRect(fromPoints r: CGRect, image: CGImage, screenSizePoints: CGSize) -> CGRect {
        
        func clamp(_ r: CGRect, to bounds: CGRect) -> CGRect {
            let x = max(bounds.minX, min(r.minX, bounds.maxX))
            let y = max(bounds.minY, min(r.minY, bounds.maxY))
            let w = max(0, min(r.width, bounds.maxX - x))
            let h = max(0, min(r.height, bounds.maxY - y))
            return CGRect(x: x, y: y, width: w, height: h)
        }
        
        
        let imageSize: CGSize = CGSize(width: image.width, height: image.height)
        
        let sx = imageSize.width / screenSizePoints.width
        let sy = imageSize.height / screenSizePoints.height
        let x = r.origin.x * sx
        let y = r.origin.y * sy
        let w = r.size.width * sx
        let h = r.size.height * sy
        
        
        let pixelRect = CGRect(x: floor(x), y: floor(y), width: floor(w), height: floor(h))
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let clamped = clamp(pixelRect, to: bounds)
        
        return clamped
    }
}

#endif
