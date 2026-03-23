//
//  ScreenRecordService+getRecordingOutputErrorMessage.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import ScreenCaptureKit

extension ScreenRecordService {
    public func getRecordingOutputErrorMessage() -> String? {
        recordingOutputErrorMessage
    }
}

extension ScreenRecordService: SCRecordingOutputDelegate {
    nonisolated public func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
    
    nonisolated public func recordingOutput(
        _ recordingOutput: SCRecordingOutput,
        didFailWithError error: any Error
    ) {
        Task { @MainActor [weak self] in
            self?.recordingOutputErrorMessage = error.localizedDescription
        }
    }
    
    nonisolated public func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {}
}
