//
//  AudioEngine.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/4/26.
//

import Foundation
import AVFoundation

@Observable
public final class AudioEngine {
    let audioInfo: AudioInfo
    private let playerCoordinator: AudioPlayerCoordinator
    
    public var progress: Double {
        playerCoordinator.progress
    }
    
    public var totalDuration: Double {
        playerCoordinator.totalDuration
    }
    
    public var currentTime: CGFloat {
        playerCoordinator.currentTime
    }
    
    public private(set) var isPlaying = false
    
    public var start : Float64 = 0.0
    public var end   : Float64 = 1.0
    
    public init(audioInfo: AudioInfo) async throws {
        self.audioInfo = audioInfo
        self.playerCoordinator = try await AudioPlayerCoordinator(audioInfo: audioInfo)
    }
    
    public func updatePlayer() async throws {
        try await playerCoordinator.updatePlayer()
    }
    public func updatePlayer(with clip: AudioInfo) async throws {
        playerCoordinator.clips.append(clip)
        try await playerCoordinator.updatePlayer()
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
