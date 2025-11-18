//
//  ScreenRecordProviding.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import AppKit
import ScreenCaptureKit

@MainActor
public protocol ScreenRecordProviding {
    
    var onScreenFrame: ScreenFrameHandler? {get set}
    var onAudioFrame:  ScreenFrameHandler? {get set}

    
    func hasScreenRecordPermission() -> Bool
    func startRecording(
        scale : VideoScale,
        showsCursor: Bool,
        capturesAudio: Bool
    )
    func stopRecording() async
}


public typealias ScreenFrameHandler = @Sendable (CMSampleBuffer) -> Void
#endif
