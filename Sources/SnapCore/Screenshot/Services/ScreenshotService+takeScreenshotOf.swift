//
//  ScreenshotService+takeScreenshotOf.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenshotService {
    public func takeScreenshot(of screen: NSScreen, croppingTo rect: CGRect) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Get current app to exclude
            let currentApp = NSRunningApplication.current
            let excludedApps = content.applications.filter { $0.bundleIdentifier == currentApp.bundleIdentifier }
            
            let normalizedRect = Self.normalizedCropRect(from: rect, on: screen)
            let shouldCrop = normalizedRect.width > 0 && normalizedRect.height > 0
            return try await captureScreen(
                screen,
                content: content,
                excludedApps: excludedApps,
                sourceRect: shouldCrop ? normalizedRect : nil
            )
        } catch {
            return nil
        }
    }
}

#endif
