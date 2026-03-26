//
//  Playback.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

#if os(macOS)
import AppKit
import CoreMedia
import SwiftUI

@Observable
public final class PlaybackEngine {
    let recordingInfo: RecordingInfo
    
    private var isInPlayableArea: Bool {
        return progress >= start && progress <= end
    }
    
    public var currentTime: Float64 {
        imageCoordinator.currentTime
    }
    public var progress: Double {
        imageCoordinator.progress
    }
    
    public var currentMouse: CurrentMouseInfo? {
        if isInPlayableArea {
            return imageCoordinator.currentMouse
        } else {
            return nil
        }
    }
    
    public var currentCursorMotionState: CursorMotionState? {
        if isInPlayableArea {
            return imageCoordinator.cursorMotionState
        } else {
            return nil
        }
    }
    
    public var currentFrame: CGImage? {
        if isInPlayableArea {
            return imageCoordinator.currentFrame
        } else {
            return nil
        }
    }
    
    public var currentFrameColor: Color? {
        if isInPlayableArea, let c = imageCoordinator.currentFrameColor {
            return Color(nsColor: c)
        } else {
            return nil
        }
    }

    
    public var totalDuration: Float64 {
        playerCoordinator.totalDuration
    }
    
    public var start : Float64 = 0.0
    public var end   : Float64 = 1.0

    public var imageCoordinator : PlaybackImageCoordinator
    public var playerCoordinator : PlaybackPlayerCoordinator

    public init(recordingInfo: RecordingInfo) async {
        self.recordingInfo = recordingInfo
        
        guard let url = await recordingInfo.url else {
            fatalError("Recording URL is Nil")
        }
        
        let imageCoordinator = PlaybackImageCoordinator(
            recordingInfo: recordingInfo
        )
        let playerCoordinator = PlaybackPlayerCoordinator(
            url: url,
            videoOutput: imageCoordinator.videoOutput
        )
        // Now assign to stored properties
        self.imageCoordinator = imageCoordinator
        self.playerCoordinator = playerCoordinator

        self.imageCoordinator.assign(to: playerCoordinator.player)
        self.imageCoordinator.startRendering()
    }
    
    public func play() {
        playerCoordinator.play()
    }
    public func pause() {
        playerCoordinator.pause()
    }
    public func seek(to time: CMTime) {
        playerCoordinator.seek(to: time)
    }
    public func stop() {
        playerCoordinator.pause()
        playerCoordinator.seek(to: .zero)
    }
    
    deinit {
        imageCoordinator.stopRendering()
    }
}
#endif
