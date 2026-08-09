//
//  ScreenRecordService+startRecording.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit
import CoreGraphics

extension ScreenRecordService {
    /// Starts the main display without relying on the system content picker.
    ///
    /// This is intended for appliance-style mirroring clients that always send
    /// the active Mac display. Unlike the picker entry point, failures are
    /// surfaced to the caller instead of leaving the UI waiting indefinitely.
    public func startRecordingMainDisplay(
        scale: VideoScale = .native,
        showsCursor: Bool = true,
        capturesAudio: Bool = true,
        fps: FPS = .fps120
    ) async throws {
        guard hasScreenRecordPermission() else {
            CGRequestScreenCaptureAccess()
            throw ScreenRecordStartError.permissionRequired
        }

        self.showsCursor = showsCursor
        self.capturesAudio = capturesAudio
        self.scale = scale
        self.fps = fps

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let mainDisplayID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainDisplayID })
                ?? content.displays.first else {
            throw ScreenRecordStartError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        cachedFilter = filter
        try await startCapture(with: filter)
    }

    public func startRecording(
        scale: VideoScale = .native,
        showsCursor: Bool = true,
        capturesAudio: Bool = true,
        fps: FPS = .fps120
    ) {
        guard hasScreenRecordPermission() else {
            CGRequestScreenCaptureAccess()
            return
        }
        
        self.showsCursor = showsCursor
        self.capturesAudio = capturesAudio
        self.scale = scale
        self.fps = fps
        
        if let cached = cachedFilter {
            Task {
                try? await startCapture(with: cached)
            }
            return
        }
        
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleDisplay]
        
        let picker = SCContentSharingPicker.shared
        picker.configuration = config
        picker.add(self)
        picker.isActive = true
        picker.present()
    }
}

public enum ScreenRecordStartError: LocalizedError {
    case permissionRequired
    case noDisplayAvailable

    public var errorDescription: String? {
        switch self {
        case .permissionRequired:
            "Screen Recording permission is required. Enable it in System Settings, then try again."
        case .noDisplayAvailable:
            "No display is available to capture."
        }
    }
}

#endif
