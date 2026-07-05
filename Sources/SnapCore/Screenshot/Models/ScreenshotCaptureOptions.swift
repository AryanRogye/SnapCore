//
//  ScreenshotCaptureOptions.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/1/26.
//

#if os(macOS)
public struct ScreenshotCaptureOptions: Sendable {
    public var showsCursor: Bool

    public nonisolated static let `default` = Self(showsCursor: true)

    public init(showsCursor: Bool = true) {
        self.showsCursor = showsCursor
    }
}
#endif
