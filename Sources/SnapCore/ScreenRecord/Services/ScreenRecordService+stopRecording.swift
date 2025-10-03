//
//  ScreenRecordService+stopRecording.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

import ScreenCaptureKit

extension ScreenRecordService {
    public func stopRecording() async {
        if let stream = stream, let output = streamOutput {
            try? stream.removeStreamOutput(output, type: .screen)
            try? stream.removeStreamOutput(output, type: .audio)
            try? await stream.stopCapture()
        }
        
        stream = nil
        streamOutput = nil
        SCContentSharingPicker.shared.isActive = false
    }
}
