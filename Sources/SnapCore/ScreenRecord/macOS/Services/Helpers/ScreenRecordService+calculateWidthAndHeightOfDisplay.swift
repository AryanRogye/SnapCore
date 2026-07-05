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
        case .normal, .medium, .high, .ultra:
            let aspectRatio = CGFloat(nativeDimensions.width) / CGFloat(nativeDimensions.height)
            let height = scale.value
            let width = Int((CGFloat(height) * aspectRatio).rounded(.toNearestOrAwayFromZero))
            return (width, height)
        case .native:
            return (nativeDimensions.width, nativeDimensions.height)
        }
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
