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
        sourceRect: CGRect? = nil,
        options: ScreenshotCaptureOptions = .default
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
        let pointPixelScale = max(CGFloat(filter.pointPixelScale), 1)
        let sourceRect = sourceRect.map {
            Self.pixelAlignedSourceRect($0, pointPixelScale: pointPixelScale)
        }
        let pixelSize = Self.targetPixelSize(
            for: display,
            pointPixelScale: pointPixelScale,
            sourceRect: sourceRect
        )
        
        config.width = Int(pixelSize.width)
        config.height = Int(pixelSize.height)
        config.scalesToFit = false
        config.preservesAspectRatio = true
        config.showsCursor = options.showsCursor
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.captureResolution = .best
        
        if let rect = sourceRect {
            config.sourceRect = rect
        }
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    private static func targetPixelSize(
        for display: SCDisplay,
        pointPixelScale: CGFloat,
        sourceRect: CGRect?
    ) -> CGSize {
        let nativeSize = nativePixelSize(for: display, pointPixelScale: pointPixelScale)
        let nativeWidth = Int(nativeSize.width)
        let nativeHeight = Int(nativeSize.height)

        if let rect = sourceRect {
            let width = max(1, min(nativeWidth, Int((rect.width * pointPixelScale).rounded(.up))))
            let height = max(1, min(nativeHeight, Int((rect.height * pointPixelScale).rounded(.up))))
            return CGSize(width: width, height: height)
        } else {
            return CGSize(width: nativeWidth, height: nativeHeight)
        }
    }

    private static func nativePixelSize(for display: SCDisplay, pointPixelScale: CGFloat) -> CGSize {
        let filterSize = CGSize(
            width: CGFloat(max(1, Int((CGFloat(display.width) * pointPixelScale).rounded(.up)))),
            height: CGFloat(max(1, Int((CGFloat(display.height) * pointPixelScale).rounded(.up))))
        )
        let displaySize = CGSize(
            width: CGFloat(CGDisplayPixelsWide(display.displayID)),
            height: CGFloat(CGDisplayPixelsHigh(display.displayID))
        )

        guard displaySize.width > 0, displaySize.height > 0 else {
            return filterSize
        }

        return displaySize.area >= filterSize.area ? displaySize : filterSize
    }

    static func pixelAlignedSourceRect(_ rect: CGRect, pointPixelScale: CGFloat) -> CGRect {
        let scale = max(pointPixelScale, 1)
        let rect = rect.standardized
        let minX = (rect.minX * scale).rounded(.down) / scale
        let minY = (rect.minY * scale).rounded(.down) / scale
        let maxX = (rect.maxX * scale).rounded(.up) / scale
        let maxY = (rect.maxY * scale).rounded(.up) / scale

        return CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}

private extension CGSize {
    var area: CGFloat {
        width * height
    }
}

#endif
