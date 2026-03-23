//
//  ScreenRecordService+startRecording.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenRecordService {
    public func startRecording(
        scale: VideoScale = .normal,
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

#endif
