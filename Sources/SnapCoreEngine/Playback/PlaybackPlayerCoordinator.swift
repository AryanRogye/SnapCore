//
//  PlaybackPlayerCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

#if os(macOS)
import AVFoundation

@Observable
public final class PlaybackPlayerCoordinator {
    
    var player : AVPlayer
    
    var totalDuration: Float64 = 0
    
    init(
        url: URL,
        videoOutput: AVPlayerItemVideoOutput
    ) {
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.add(videoOutput)
        
        player = AVPlayer(playerItem: playerItem)
        Task {
            await loadDuration(from: asset)
        }
    }
    
    private func loadDuration(from asset: AVURLAsset) async {
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            await setDuration(seconds)
        } catch {
            print("Failed to load duration:", error)
        }
    }

    @MainActor
    private func setDuration(_ seconds: Float64) {
        if seconds.isFinite, seconds > 0 {
            totalDuration = seconds
        }
    }
    
    public func play() {
        player.play()
    }
    
    public func pause() {
        player.pause()
    }
    
    public func seek(to time: CMTime) {
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: CMTime(value: 1, timescale: 60))
    }
}
#endif
