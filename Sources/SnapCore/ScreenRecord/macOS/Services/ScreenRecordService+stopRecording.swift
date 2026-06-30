//
//  ScreenRecordService+stopRecording.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import ScreenCaptureKit

extension ScreenRecordService {
    public func stopRecording() async {
        if let stream = stream, let output = streamOutput {
            if let _ = recordingOutputStorage as? SCRecordingOutput {
                self.recordingOutputStorage = nil
            }
            try? stream.removeStreamOutput(output, type: .screen)
            try? stream.removeStreamOutput(output, type: .audio)
            try? await stream.stopCapture()
        }
        
        detachOutput()
        
        stream = nil
        streamOutput = nil
        recordingOutputStorage = nil
        pendingRecordingOutputURL = nil
        SCContentSharingPicker.shared.isActive = false
    }
    
    internal func detachOutput() {
        screenFrameTask?.cancel()
        audioFrameTask?.cancel()
        screenFrameTask = nil
        audioFrameTask = nil
        streamOutput = nil
    }
}

#endif
