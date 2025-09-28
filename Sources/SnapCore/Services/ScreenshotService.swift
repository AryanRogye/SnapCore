//
//  ScreenshotService.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/26/25.
//


import AppKit
import ScreenCaptureKit

// MARK: - Implementation
/// Default implementation backed by ScreenCaptureKit.
///     Fetches shareable content and exclude the current app
///     Selects the primary display
///     Configures stream dimensions to match the display
///     Captures a single `CGImage` via `SCScreenshotManager`
public final class ScreenshotService: ScreenshotProviding {
    public init() {}
}
