//
//  ScreenshotService+captureScreen.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import ScreenCaptureKit
import CoreGraphics

extension ScreenshotService {
    internal func captureScreen(
        _ screen: NSScreen,
        content: SCShareableContent,
        excludedApps: [SCRunningApplication],
        sourceRect: CGRect? = nil
    ) async throws -> CGImage {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
            throw NSError(domain: "ScreenshotError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find matching display"])
        }
        
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )
        
        let config = SCStreamConfiguration()
        let pixelSize = Self.targetPixelSize(for: screen, displayID: display.displayID, sourceRect: sourceRect)
        
        config.width = Int(pixelSize.width)
        config.height = Int(pixelSize.height)
        config.scalesToFit = false
        config.preservesAspectRatio = true
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        
        if let rect = sourceRect {
            config.sourceRect = rect
        }
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    private static func targetPixelSize(for screen: NSScreen, displayID: CGDirectDisplayID, sourceRect: CGRect?) -> CGSize {
        let nativeWidth = CGFloat(CGDisplayPixelsWide(displayID))
        let nativeHeight = CGFloat(CGDisplayPixelsHigh(displayID))
        let screenSize = screen.frame.size
        
        guard screenSize.width > 0, screenSize.height > 0 else {
            return CGSize(width: nativeWidth, height: nativeHeight)
        }
        
        let scaleX = nativeWidth / screenSize.width
        let scaleY = nativeHeight / screenSize.height
        
        if let rect = sourceRect {
            let width = max(1, Int((rect.width * scaleX).rounded(.down)))
            let height = max(1, Int((rect.height * scaleY).rounded(.down)))
            return CGSize(width: width, height: height)
        } else {
            return CGSize(width: nativeWidth, height: nativeHeight)
        }
    }
}

#endif


