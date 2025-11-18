//
//  ScreenshotService+hasScreenshotPermission.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenshotService {
    public func hasScreenshotPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

#endif
