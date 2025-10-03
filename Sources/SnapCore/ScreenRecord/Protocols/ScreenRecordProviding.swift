//
//  ScreenRecordProviding.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

import AppKit
import ScreenCaptureKit

@MainActor
public protocol ScreenRecordProviding {
    
    var onScreenFrame: ((CMSampleBuffer) -> Void)? {get set}
    var onAudioFrame:  ((CMSampleBuffer) -> Void)? {get set}

    
    func hasScreenRecordPermission() -> Bool
    func startRecording(
        scale : VideoScale,
        showsCursor: Bool,
        capturesAudio: Bool
    )
    func stopRecording() async
}

extension CMSampleBuffer: @unchecked Sendable {}
extension SCContentFilter: @unchecked Sendable {}
