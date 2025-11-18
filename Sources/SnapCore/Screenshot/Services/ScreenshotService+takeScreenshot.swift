//
//  ScreenshotService+takeScreenshot.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenshotService {
    /// Takes a screenshot of the main display using ScreenCaptureKit.
    ///
    /// Notes:
    /// - Requires Screen Recording permission on macOS.
    public func takeScreenshot() async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Get current app to exclude
            let currentApp = NSRunningApplication.current
            let excludedApps = content.applications.filter { $0.bundleIdentifier == currentApp.bundleIdentifier }
            
            // Use the mouse location to determine which display to capture
            let mouseLocation = NSEvent.mouseLocation
            
            guard let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) else {
                // Fallback to main screen
                guard let mainScreen = NSScreen.main else {
                    throw NSError(domain: "ScreenshotError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No screen available"])
                }
                return try await captureScreen(mainScreen, content: content, excludedApps: excludedApps)
            }
            
            return try await captureScreen(targetScreen, content: content, excludedApps: excludedApps)
        } catch {
            return nil
        }
    }
}

#endif
