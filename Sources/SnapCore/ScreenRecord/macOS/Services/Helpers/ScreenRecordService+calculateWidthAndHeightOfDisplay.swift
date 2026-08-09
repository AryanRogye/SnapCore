//
//  ScreenRecordService+calculateWidthAndHeightOfDisplay.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//
#if os(macOS)
import ScreenCaptureKit

extension ScreenRecordService {
    
    internal func calculateWidthAndHeightOfDisplay(
        display: SCDisplay,
        filter: SCContentFilter
    ) -> (width: Int, height: Int) {
        let nativeDimensions = nativePixelDimensions(for: display, filter: filter)
        
        switch scale {
        case .low, .normal, .medium, .high, .ultra:
            let aspectRatio = CGFloat(nativeDimensions.width) / CGFloat(nativeDimensions.height)
            let requestedHeight = scale.value
            let requestedWidth = Int(
                (CGFloat(requestedHeight) * aspectRatio)
                    .rounded(.toNearestOrAwayFromZero)
            )
            // ScreenCaptureKit is configured for bi-planar 4:2:0 and the live
            // stream is encoded as H.264. Both paths require chroma planes with
            // even dimensions. Mac display aspect ratios commonly turn 1080p
            // into an odd width (for example, 1663x1080), which yields audio but
            // no usable video samples.
            return (
                width: Self.evenDimension(requestedWidth),
                height: Self.evenDimension(requestedHeight)
            )
        case .native:
            return (
                width: Self.evenDimension(nativeDimensions.width),
                height: Self.evenDimension(nativeDimensions.height)
            )
        }
    }

    private static func evenDimension(_ value: Int) -> Int {
        let positive = max(value, 2)
        return positive.isMultiple(of: 2) ? positive : positive + 1
    }

    private func nativePixelDimensions(
        for display: SCDisplay,
        filter: SCContentFilter
    ) -> (width: Int, height: Int) {
        let pointPixelScale = max(CGFloat(filter.pointPixelScale), 1)
        self.lastBackingScaleFactorUsed = pointPixelScale

        let filterDimensions = (
            width: max(1, Int((CGFloat(display.width) * pointPixelScale).rounded(.up))),
            height: max(1, Int((CGFloat(display.height) * pointPixelScale).rounded(.up)))
        )
        let displayDimensions = (
            width: Int(CGDisplayPixelsWide(display.displayID)),
            height: Int(CGDisplayPixelsHigh(display.displayID))
        )

        guard displayDimensions.width > 0, displayDimensions.height > 0 else {
            return filterDimensions
        }

        let filterArea = filterDimensions.width * filterDimensions.height
        let displayArea = displayDimensions.width * displayDimensions.height
        return displayArea >= filterArea ? displayDimensions : filterDimensions
    }
}
#endif
