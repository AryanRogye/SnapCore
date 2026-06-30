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
        display: SCDisplay
    ) -> (width: Int, height: Int) {
        
        let pointWidth  = Int(display.frame.width.rounded(.down))
        let pointHeight = Int(display.frame.height.rounded(.down))
        
        /// get the screen that matches with our displayID
        let matchingScreen = NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return screenNumber == display.displayID
        }
        
        switch scale {
        case .normal, .medium, .high, .ultra:
            let aspectRatio = CGFloat(pointWidth) / CGFloat(pointHeight)
            let height = scale.value
            let width = Int(CGFloat(height) * aspectRatio)
            return (width, height)
        case .native:
            /// scale factor lets us match it to what our screen is
            let scaleFactor = matchingScreen?.backingScaleFactor ?? 2.0
            /// setting this just for info
            self.lastBackingScaleFactorUsed = scaleFactor
            
            let nativeWidth = Int(CGFloat(pointWidth) * scaleFactor)
            let nativeHeight = Int(CGFloat(pointHeight) * scaleFactor)
            return (nativeWidth, nativeHeight)
        }
    }
}
#endif
