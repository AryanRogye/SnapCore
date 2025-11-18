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
        capturesAudio: Bool = true
    ) {
        guard hasScreenRecordPermission() else {
            CGRequestScreenCaptureAccess()
            return
        }
        
        self.showsCursor = showsCursor
        self.capturesAudio = capturesAudio
        
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
