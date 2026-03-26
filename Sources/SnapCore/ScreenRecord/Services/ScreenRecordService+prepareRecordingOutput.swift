//
//  ScreenRecordService+prepareRecordingOutput.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import Foundation

#if os(macOS)
extension ScreenRecordService {
    public func prepareRecordingOutput(url: URL) {
        pendingRecordingOutputURL = url
        recordingOutputErrorMessage = nil
    }
}
#endif
