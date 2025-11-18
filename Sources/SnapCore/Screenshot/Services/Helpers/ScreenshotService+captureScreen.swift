//
//  ScreenshotService+captureScreen.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenshotService {
    internal func captureScreen(_ screen: NSScreen, content: SCShareableContent, excludedApps: [SCRunningApplication]) async throws -> CGImage {
        // Find the SCDisplay that matches this NSScreen
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
            throw NSError(domain: "ScreenshotError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find matching display"])
        }
        
        // Create filter
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )
        
        // Configure for maximum quality
        let config = SCStreamConfiguration()
        
        // Use the display's actual pixel dimensions
        config.width = Int(CGDisplayPixelsWide(display.displayID))
        config.height = Int(CGDisplayPixelsHigh(display.displayID))
        
        // Ensure high quality settings
        config.scalesToFit = false
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Capture the image
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

#endif
