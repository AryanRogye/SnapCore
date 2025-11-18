//
//  ScreenshotProviding.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/26/25.
//

#if os(macOS)
import AppKit

// MARK: - Protocol
/// Abstraction for capturing a screenshot as a `CGImage`.
///
/// Conformers handle any platform-specific permissions (e.g.,
/// Screen Recording on macOS) and return a bitmap of the current
/// display contents.
public protocol ScreenshotProviding {
    func hasScreenshotPermission() -> Bool
    /// Captures a screenshot and returns it as a `CGImage`.
    /// - Returns: A `CGImage` of the captured content.
    /// - Throws: An error if the capture fails or permission is denied.
    func takeScreenshot() async -> CGImage?
    /// Captures a screenshot of a specific `NSScreen`.
    func takeScreenshot(of screen: NSScreen, croppingTo rect: CGRect) async -> CGImage?
}

#endif
