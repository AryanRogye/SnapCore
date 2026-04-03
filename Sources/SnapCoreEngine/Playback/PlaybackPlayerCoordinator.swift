//
//  PlaybackPlayerCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

import AVFoundation

public protocol FileInfo {
    var url: URL { get set }
    var start: Float64 { get set } // trimIn normalized (source window)
    var end: Float64 { get set } // trimOut normalized (source window)
    var timelineStart: Float64  { get set } // ← where it sits on the timeline, in seconds
    var orientation: Int { get set } // degrees
    var volume: CGFloat { get set }
}

public struct VideoFileInfo: FileInfo {
    public var url: URL
    public var start: Float64
    public var end: Float64
    public var timelineStart: Float64
    public var orientation: Int
    public var volume: CGFloat
    
    public init(
        url: URL,
        start: Float64,
        end: Float64,
        timelineStart: Float64,
        orientation: Int,
        volume: CGFloat
    ) {
        self.url = url
        self.start = start
        self.end = end
        self.timelineStart = timelineStart
        self.orientation = orientation
        self.volume = volume
    }
}

public struct AudioFileInfo: FileInfo {
    public var url: URL
    public var start: Float64
    public var end: Float64
    public var timelineStart: Float64
    public var orientation: Int
    public var volume: CGFloat
    
    public init(
        url: URL,
        start: Float64,
        end: Float64,
        timelineStart: Float64,
        orientation: Int,
        volume: CGFloat
    ) {
        self.url = url
        self.start = start
        self.end = end
        self.timelineStart = timelineStart
        self.orientation = orientation
        self.volume = volume
    }
}

struct PlaybackTimelineInterval: Equatable {
    let index: Int
    let start: Double
    let end: Double
}

enum PlaybackTimelineLayout {
    static func resolvePrimaryVideo(_ intervals: [PlaybackTimelineInterval]) -> [PlaybackTimelineInterval] {
        let sortedIntervals = sorted(intervals)
        var resolvedIntervals: [PlaybackTimelineInterval] = []

        for index in sortedIntervals.indices {
            let currentInterval = sortedIntervals[index]
            let nextStart = index + 1 < sortedIntervals.count
                ? sortedIntervals[index + 1].start
                : .infinity
            let resolvedEnd = min(currentInterval.end, nextStart)

            guard resolvedEnd > currentInterval.start else {
                continue
            }

            resolvedIntervals.append(
                PlaybackTimelineInterval(
                    index: currentInterval.index,
                    start: currentInterval.start,
                    end: resolvedEnd
                )
            )
        }

        return resolvedIntervals
    }

    static func assignAudioLanes(_ intervals: [PlaybackTimelineInterval]) -> [[PlaybackTimelineInterval]] {
        let sortedIntervals = sorted(intervals)
        var laneEndTimes: [Double] = []
        var lanes: [[PlaybackTimelineInterval]] = []

        for interval in sortedIntervals {
            if let laneIndex = laneEndTimes.firstIndex(where: { $0 <= interval.start }) {
                laneEndTimes[laneIndex] = interval.end
                lanes[laneIndex].append(interval)
            } else {
                laneEndTimes.append(interval.end)
                lanes.append([interval])
            }
        }

        return lanes
    }

    private static func sorted(_ intervals: [PlaybackTimelineInterval]) -> [PlaybackTimelineInterval] {
        intervals.sorted {
            if $0.start == $1.start {
                return $0.index < $1.index
            }

            return $0.start < $1.start
        }
    }
}

@Observable
public final class PlaybackPlayerCoordinator {
    
    private struct AssetInfo {
        var asset: AVURLAsset
        var insertTime: CMTime
        var sourceRange: CMTimeRange
    }

    private struct LoadedVideoClip {
        var index: Int
        var file: VideoFileInfo
        var assetInfo: AssetInfo
        var videoTrack: AVAssetTrack
        var embeddedAudioTrack: AVAssetTrack?
        var naturalSize: CGSize
        var preferredTransform: CGAffineTransform
    }

    private struct LoadedAudioClip {
        var index: Int
        var assetInfo: AssetInfo
        var audioTrack: AVAssetTrack
    }

    public var player : AVPlayer
    let videoOutput: AVPlayerItemVideoOutput
    
    var totalDuration: Float64 = 0
    public var lastCompostion: AVMutableComposition?
    
    /// both image coordinators on macOS and iOS should set this during init
    public var onClearCurrentFrame: () -> Void = {
        
    }
    
    init(
        url: URL,
        videoOutput: AVPlayerItemVideoOutput
    ) {
        self.videoOutput = videoOutput
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
        totalDuration = seconds.isFinite && seconds > 0 ? seconds : 0
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

// MARK: - Audio And Video
extension PlaybackPlayerCoordinator {
    private var timelineTimescale: CMTimeScale {
        600
    }

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

    private func makeInterval(
        index: Int,
        assetInfo: AssetInfo
    ) -> PlaybackTimelineInterval {
        PlaybackTimelineInterval(
            index: index,
            start: assetInfo.insertTime.seconds,
            end: assetInfo.insertTime.seconds + assetInfo.sourceRange.duration.seconds
        )
    }

    private func makeResolvedSourceRange(
        from sourceRange: CMTimeRange,
        using interval: PlaybackTimelineInterval
    ) -> CMTimeRange {
        let duration = CMTime(seconds: interval.end - interval.start, preferredTimescale: timelineTimescale)
        return CMTimeRange(start: sourceRange.start, duration: duration)
    }
    
    @MainActor
    public func replaceAllFiles(
        video: [VideoFileInfo],
        audio: [AudioFileInfo]
    ) async throws {
        let composition = AVMutableComposition()
        
        let loadedVideoClips = try await loadVideoClips(video)
        let resolvedVideoIntervals = PlaybackTimelineLayout.resolvePrimaryVideo(
            loadedVideoClips.map { makeInterval(index: $0.index, assetInfo: $0.assetInfo) }
        )
        let loadedVideoClipsByIndex = Dictionary(
            uniqueKeysWithValues: loadedVideoClips.map { ($0.index, $0) }
        )
        
        let loadedAudioClips = try await loadAudioClips(audio)
        let explicitAudioLanes = PlaybackTimelineLayout.assignAudioLanes(
            loadedAudioClips.map { makeInterval(index: $0.index, assetInfo: $0.assetInfo) }
        )
        let loadedAudioClipsByIndex = Dictionary(
            uniqueKeysWithValues: loadedAudioClips.map { ($0.index, $0) }
        )
        
        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        // Build the video composition before the loop so we can set renderSize inside it
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = .zero // will be set from the first clip's actual display size
        
        let compVideoTrack = resolvedVideoIntervals.isEmpty
        ? nil
        : composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        for resolvedInterval in resolvedVideoIntervals {
            guard
                let compVideoTrack,
                let clip = loadedVideoClipsByIndex[resolvedInterval.index]
            else {
                continue
            }
            
            let insertTime = CMTime(seconds: resolvedInterval.start, preferredTimescale: timelineTimescale)
            let sourceRange = makeResolvedSourceRange(from: clip.assetInfo.sourceRange, using: resolvedInterval)
            
            // Insert this clip's time range into the composition's single primary video track.
            // Overlaps are trimmed ahead of time so video never layers.
            try compVideoTrack.insertTimeRange(sourceRange, of: clip.videoTrack, at: insertTime)
            
            // naturalSize is the raw sensor size — for portrait videos this is
            // e.g. 1080x1920 but may be reported as 1920x1080 before transform is applied
            let naturalSize = clip.naturalSize
            
            // preferredTransform is the rotation metadata baked into the file by the camera.
            // e.g. a portrait iPhone video has a 90° rotation stored here
            let preferredTransform = clip.preferredTransform
            
            // Decide which transform to apply to the layer:
            // - orientation == 0: trust the asset's own metadata
            // - otherwise: apply the user-specified rotation on top
            let userTransform = clip.file.orientation != 0
            ? CGAffineTransform(rotationAngle: CGFloat(clip.file.orientation) * .pi / 180)
            : .identity
            
            let finalTransform = preferredTransform.concatenating(userTransform)
            
            let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(finalTransform)
            let displaySize = CGSize(
                width: abs(transformedRect.width),
                height: abs(transformedRect.height)
            )
            
            if videoComposition.renderSize == .zero {
                videoComposition.renderSize = displaySize
            }
            
            var scaledTransform = finalTransform
            if clip.file.orientation != 0, videoComposition.renderSize != .zero {
                let renderSize = videoComposition.renderSize
                let scaleX = renderSize.width / displaySize.width
                let scaleY = renderSize.height / displaySize.height
                let scale = min(scaleX, scaleY)
                
                scaledTransform = finalTransform.scaledBy(x: scale, y: scale)
                
                let scaledRect = CGRect(origin: .zero, size: naturalSize).applying(scaledTransform)
                let offsetX = (renderSize.width - abs(scaledRect.width)) / 2 - scaledRect.minX
                let offsetY = (renderSize.height - abs(scaledRect.height)) / 2 - scaledRect.minY
                scaledTransform = scaledTransform.translatedBy(x: offsetX / scale, y: offsetY / scale)
            }
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
            layerInstruction.setTransform(scaledTransform, at: insertTime)
            layerInstruction.setTransform(.identity, at: CMTimeAdd(insertTime, sourceRange.duration))
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: insertTime, duration: sourceRange.duration)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)
        }
        
        let resolvedVideoAudioLanes = PlaybackTimelineLayout.assignAudioLanes(
            resolvedVideoIntervals
        )
        let resolvedVideoAudioByIndex = Dictionary(
            uniqueKeysWithValues: resolvedVideoIntervals.map { ($0.index, $0) }
        )
        
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        
        for lane in resolvedVideoAudioLanes {
            
            guard let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }
            
            let params = AVMutableAudioMixInputParameters(track: compAudioTrack)
            
            for interval in lane {
                guard
                    let clip = loadedVideoClipsByIndex[interval.index],
                    let resolvedInterval = resolvedVideoAudioByIndex[clip.index],
                    let audioTrack = clip.embeddedAudioTrack
                else {
                    continue
                }
                
                let insertTime = CMTime(seconds: resolvedInterval.start, preferredTimescale: timelineTimescale)
                let sourceRange = makeResolvedSourceRange(from: clip.assetInfo.sourceRange, using: resolvedInterval)
                try compAudioTrack.insertTimeRange(sourceRange, of: audioTrack, at: insertTime)
                params.setVolume(Float(clip.file.volume), at: insertTime)
            }
            
            audioMixParams.append(params)
        }
        
        for lane in explicitAudioLanes {
            guard let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                continue
            }
            
            let params = AVMutableAudioMixInputParameters(track: compAudioTrack)
            
            for interval in lane {
                guard let clip = loadedAudioClipsByIndex[interval.index] else {
                    continue
                }
                
                let insertTime = CMTime(seconds: interval.start, preferredTimescale: timelineTimescale)
                try compAudioTrack.insertTimeRange(clip.assetInfo.sourceRange, of: clip.audioTrack, at: insertTime)
                params.setVolume(Float(audio[interval.index].volume), at: insertTime)
            }
            
            audioMixParams.append(params)
        }
        
        videoComposition.instructions = instructions
        
        // Swap in the new composition — addVideoOutput attaches our pixel buffer
        // tap so the display link can pull frames for rendering
        let newItem = AVPlayerItem(asset: composition)
        if !instructions.isEmpty, videoComposition.renderSize != .zero {
            newItem.videoComposition = videoComposition
        }
        newItem.add(videoOutput)
        if !audioMixParams.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = audioMixParams
            newItem.audioMix = audioMix
        }
        player.replaceCurrentItem(with: newItem)
        
        setDuration(composition.duration.seconds)
        
        lastCompostion = composition
        
        // Tell the image coordinator to drop the current frame so it doesn't
        // flash stale content while the new item loads
        onClearCurrentFrame()
    }

    private func loadVideoClips(
        _ files: [VideoFileInfo]
    ) async throws -> [LoadedVideoClip] {
        var loadedClips: [LoadedVideoClip] = []

        for (index, file) in files.enumerated() {
            let assetInfo = try await createAsset(file: file)
            let videoTrack = try await assetInfo.asset.loadTracks(withMediaType: .video).first

            guard let videoTrack else {
                continue
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)
            let embeddedAudioTrack = try await assetInfo.asset.loadTracks(withMediaType: .audio).first

            loadedClips.append(
                LoadedVideoClip(
                    index: index,
                    file: file,
                    assetInfo: assetInfo,
                    videoTrack: videoTrack,
                    embeddedAudioTrack: embeddedAudioTrack,
                    naturalSize: naturalSize,
                    preferredTransform: preferredTransform
                )
            )
        }

        return loadedClips
    }

    private func loadAudioClips(
        _ files: [AudioFileInfo]
    ) async throws -> [LoadedAudioClip] {
        var loadedClips: [LoadedAudioClip] = []

        for (index, file) in files.enumerated() {
            let assetInfo = try await createAsset(file: file)
            let audioTrack = try await assetInfo.asset.loadTracks(withMediaType: .audio).first

            guard let audioTrack else {
                continue
            }

            loadedClips.append(
                LoadedAudioClip(
                    index: index,
                    assetInfo: assetInfo,
                    audioTrack: audioTrack
                )
            )
        }

        return loadedClips
    }
}
