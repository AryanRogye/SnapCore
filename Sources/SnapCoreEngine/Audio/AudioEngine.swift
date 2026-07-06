//
//  AudioEngine.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/4/26.
//

import Foundation
import AVFoundation

@Observable
@MainActor
public final class AudioEngine {
    let audioInfo: AudioInfo
    private let playerCoordinator: AudioPlayerCoordinator
    
    public var progress: Double = 0
    public var totalDuration: Double = 0
    public var currentTime: CGFloat = 0
    
    public private(set) var isPlaying = false
    
    public var start : Float64 = 0.0
    public var end   : Float64 = 1.0
    
    public init(audioInfo: AudioInfo) async throws {
        self.audioInfo = audioInfo
        
        let snapshot = AudioInfoSnapshot.init(from: audioInfo)
        self.playerCoordinator = try await AudioPlayerCoordinator(
            audioInfo: snapshot
        )
        self.playerCoordinator.setClosures(
            onProgress: { progress in
                self.progress = progress
            },
            onCurrentTime: { currentTime in
                self.currentTime = currentTime
            },
            onTotalDuration: { duration in
                self.totalDuration = duration
            }
        )
    }
    
    public func updatePlayer(clips: [AudioInfo]) {
        let snapshots = clips.map { AudioInfoSnapshot(from: $0) }
        playerCoordinator.updatePlayer(from: snapshots)
    }
    
    public func seek(to time: CMTime) {
        playerCoordinator.seek(to: time)
    }
    
    public func play() {
        playerCoordinator.play()
        isPlaying = true
    }
    
    public func pause() {
        playerCoordinator.pause()
        isPlaying = false
    }
}
