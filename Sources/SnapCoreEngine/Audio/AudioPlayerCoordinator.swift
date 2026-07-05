//
//  AudioPlayerCoordinator.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/4/26.
//


import AVFoundation

@Observable
final class AudioPlayerCoordinator {
    
    private struct AssetInfo {
        var asset: AVURLAsset
        var insertTime: CMTime
        var sourceRange: CMTimeRange
    }
    
    private struct LoadedAudioClip {
        var index: Int
        var assetInfo: AssetInfo
        var audioTrack: AVAssetTrack
    }
    
    @ObservationIgnored
    public var player : AVPlayer
    @ObservationIgnored
    private var timeObserver: Any?
    @ObservationIgnored
    public var lastCompostion: AVMutableComposition?

    public var progress: Double = 0
    public var currentTime: CGFloat = 0
    public var totalDuration: Float64 = 0
    
    var clips: [AudioInfo] = []
    
    public func updatePlayer() async throws {
        
        let composition = AVMutableComposition()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        for clip in clips {
            guard let url = clip.url else { continue }
            
            let asset = AVURLAsset(url: url)
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }
            
            let assetDuration = try await asset.load(.duration)
            
            let sourceStart = CMTime(
                seconds: clip.start * assetDuration.seconds,
                preferredTimescale: timelineTimescale
            )
            
            let sourceDuration = CMTime(
                seconds: (clip.end - clip.start) * assetDuration.seconds,
                preferredTimescale: timelineTimescale
            )
            
            let sourceRange = CMTimeRange(
                start: sourceStart,
                duration: sourceDuration
            )
            
            let insertTime = CMTime(
                seconds: clip.timelineStart,
                preferredTimescale: timelineTimescale
            )
            
            guard let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }
            
            try compositionTrack.insertTimeRange(
                sourceRange,
                of: audioTrack,
                at: insertTime
            )
            
            let params = AVMutableAudioMixInputParameters(track: compositionTrack)
            params.setVolume(Float(clip.volume), at: insertTime)
            audioMixParams.append(params)
        }
        
        let item = await AVPlayerItem(asset: composition)
        
        if !audioMixParams.isEmpty {
            Task { @MainActor in
                let mix = AVMutableAudioMix()
                mix.inputParameters = audioMixParams
                item.audioMix = mix
            }
        }
        
        player.replaceCurrentItem(with: item)
        await setDuration(composition.duration.seconds)
        
        lastCompostion = composition
    }
    
    init(audioInfo: AudioInfo) async throws {
        guard let url = audioInfo.url else {
            fatalError("Audio URL is nil For AudioPlayerCoordinator")
        }
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        self.clips.append(audioInfo)
        
        try await updatePlayer()
        addTimeObserver()
    }
    
    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }
    
    var isPlaying: Bool {
        return player.rate != 0 && player.error == nil
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
        player.seek(to: .zero)
    }
    
    func seek(to time: CMTime) {
        player.seek(to: time)
    }
    
    @MainActor
    private func setDuration(_ seconds: Float64) {
        totalDuration = seconds.isFinite && seconds > 0 ? seconds : 0
    }
}

// MARK: - Helpers
extension AudioPlayerCoordinator {
    
    private var timelineTimescale: CMTimeScale {
        600
    }
    
    /// Force AudioFileInfo
    private func createAsset<T : FileInfo>(file: T) async throws -> AssetInfo {
        let asset = AVURLAsset(url: file.url)
        let assetDuration = try await asset.load(.duration)
        let sourceStart = CMTime(seconds: file.start * assetDuration.seconds, preferredTimescale: timelineTimescale)
        let sourceDuration = CMTime(seconds: (file.end - file.start) * assetDuration.seconds, preferredTimescale: timelineTimescale)
        
        let sourceRange = CMTimeRange(start: sourceStart, duration: sourceDuration)
        let insertTime = CMTime(seconds: file.timelineStart, preferredTimescale: timelineTimescale)
        
        return AssetInfo(
            asset: asset,
            insertTime: insertTime,
            sourceRange: sourceRange
        )
    }
    
    /// Function Observes the `AVPlayer` and updates the currentTime
    /// and progress as it updates
    private func addTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            
            let elapsed = CMTimeGetSeconds(time)
            let duration = self.totalDuration
            
            self.currentTime = elapsed
            self.progress = duration > 0 ? elapsed / duration : 0
        }
    }
}
