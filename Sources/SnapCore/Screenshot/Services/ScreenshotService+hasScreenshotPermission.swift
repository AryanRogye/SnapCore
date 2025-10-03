//
//  ScreenshotService+hasScreenshotPermission.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

import ScreenCaptureKit

extension ScreenshotService {
    public func hasScreenshotPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
