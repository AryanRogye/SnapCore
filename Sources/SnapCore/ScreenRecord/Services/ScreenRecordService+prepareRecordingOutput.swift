//
//  ScreenRecordService+prepareRecordingOutput.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import Foundation

extension ScreenRecordService {
    public func prepareRecordingOutput(url: URL) {
        pendingRecordingOutputURL = url
        recordingOutputErrorMessage = nil
    }
}
