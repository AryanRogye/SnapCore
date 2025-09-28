//
//  ScreenshotService+takeScreenshotOf.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

import ScreenCaptureKit

extension ScreenshotService {
    public func takeScreenshot(of screen: NSScreen, croppingTo rect: CGRect) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Get current app to exclude
            let currentApp = NSRunningApplication.current
            let excludedApps = content.applications.filter { $0.bundleIdentifier == currentApp.bundleIdentifier }
            
            let image = try await captureScreen(screen, content: content, excludedApps: excludedApps)
            
            /// Get Clamped Pixel Rect
            let clamped = Self.pixelCropRect(
                fromPoints: rect,
                image: image,
                screenSizePoints: screen.frame.size
            )
            
            /// If We Have Bad Size just return original image
            guard clamped.width > 0, clamped.height > 0 else {
                return image
            }
            
            if let image = image.cropping(to: clamped) {
                return image
            }
            return image
            
        } catch {
            return nil
        }
    }
}
