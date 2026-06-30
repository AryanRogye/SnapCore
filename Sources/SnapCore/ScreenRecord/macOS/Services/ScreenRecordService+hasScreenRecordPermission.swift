//
//  ScreenRecordService+hasScreenRecordPermission.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenRecordService {
    nonisolated public func hasScreenRecordPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
}

#endif
