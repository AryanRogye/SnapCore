//
//  AudioPlayerCoordinator.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/4/26.
//


import AVFoundation

struct CompositionResult {
    let item: AVPlayerItem
    let mix: AVMutableAudioMix?
    let composition: AVMutableComposition
    let duration: Double
}

enum AudioCompositionBuilder {
    
    private static var timelineTimescale: CMTimeScale {
        600
    }

    static func build(from clips: [AudioInfoSnapshot]) async throws -> CompositionResult {
        
        let composition = AVMutableComposition()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []

        for clip in clips {
            do {
                guard let url = clip.url else { continue }
                
                let asset = AVURLAsset(url: url)
                guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                    continue
                }
                
                let assetDuration = try await asset.load(.duration)
                
                let sourceStart = CMTime(
                    seconds: clip.start * assetDuration.seconds,
                    preferredTimescale: self.timelineTimescale
                )
                
                let sourceDuration = CMTime(
                    seconds: (clip.end - clip.start) * assetDuration.seconds,
                    preferredTimescale: self.timelineTimescale
                )
                
                let sourceRange = CMTimeRange(
                    start: sourceStart,
                    duration: sourceDuration
                )
                
                let insertTime = CMTime(
                    seconds: clip.timelineStart,
                    preferredTimescale: self.timelineTimescale
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
            } catch {
                continue
            }
        }
        
        let item = await AVPlayerItem(asset: composition)
        
        let mix: AVMutableAudioMix?
        if !audioMixParams.isEmpty {
            let a_mix = AVMutableAudioMix()
            a_mix.inputParameters = audioMixParams
            mix = a_mix
        } else {
            mix = nil
        }
        
        return .init(
            item: item,
            mix: mix,
            composition: composition,
            duration: composition.duration.seconds
        )
    }
}

@MainActor
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
    
    private var player : AVPlayer
    private var timeObserver: Any?
    private var totalDuration: Float64 = 0
    private var updatePlayerTask: Task<Void, Never>?
    
    public var onProgress: (@MainActor (Double) -> Void)?
    public var onCurrentTime: (@MainActor (CGFloat) -> Void)?
    public var onTotalDuration: (@MainActor (Float64) -> Void)?
    
    public func updatePlayer(from clips: [AudioInfoSnapshot]) {
        
        updatePlayerTask?.cancel()
        updatePlayerTask = Task(priority: .userInitiated) {
            do {
                let result = try await AudioCompositionBuilder.build(from: clips)
                
                try Task.checkCancellation()

                Task { @MainActor in
                    if let mix = result.mix {
                        result.item.audioMix = mix
                    }
                    self.player.replaceCurrentItem(with: result.item)
                    self.setDuration(result.composition.duration.seconds)
                }
            } catch is CancellationError {
                /// dont do anything
            } catch {
                /// dont do anything
            }
        }
    }

    
    init(
        audioInfo: AudioInfoSnapshot,
    ) async throws {
        guard let url = audioInfo.url else {
            fatalError("Audio URL is nil For AudioPlayerCoordinator")
        }
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        updatePlayer(from: [audioInfo])
        addTimeObserver()
    }
    
    public func setClosures(
        onProgress: @escaping (Double) -> Void,
        onCurrentTime: @escaping (CGFloat) -> Void,
        onTotalDuration: @escaping (Float64) -> Void
    ) {
        self.onProgress = onProgress
        self.onCurrentTime = onCurrentTime
        self.onTotalDuration = onTotalDuration
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
    
    private func setDuration(_ seconds: Float64) {
        totalDuration = seconds.isFinite && seconds > 0 ? seconds : 0
        Task { @MainActor in
            onTotalDuration?(totalDuration)
        }
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
            
            Task { @MainActor in
                let duration = self.totalDuration
                self.onCurrentTime?(elapsed)
                self.onProgress?(duration > 0 ? elapsed / duration : 0)
            }
        }
    }
}
