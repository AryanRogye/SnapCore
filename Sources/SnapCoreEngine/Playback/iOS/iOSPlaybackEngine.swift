//
//  PlaybackEngine.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/31/26.
//

#if os(iOS)
import Foundation
import CoreImage
import CoreMedia

@Observable
public final class PlaybackEngine {
    
    var mediaURL: URL
    public var hasLoaded = false
    private var previewSeekGeneration: UInt = 0
    
    private var isInPlayableArea: Bool {
        return progress >= start && progress <= end
    }
    
    public var currentTime: Float64 {
        imageCoordinator.currentTime
    }
    public var progress: Double {
        imageCoordinator.progress
    }
    
    public var totalDuration: Float64 {
        playerCoordinator.totalDuration
    }
    
    public var currentFrame: CGImage? {
        if isInPlayableArea {
            return imageCoordinator.currentFrame
        } else {
            return nil
        }
    }
    
    public var start : Float64 = 0.0
    public var end   : Float64 = 1.0
    
    public var imageCoordinator : PlaybackImageCoordinator
    public var playerCoordinator : PlaybackPlayerCoordinator

    public init() {
        let url = URL(fileURLWithPath: "/dev/null") // temp dummy
        let image = PlaybackImageCoordinator(url: url)
        let player = PlaybackPlayerCoordinator(
            url: url,
            videoOutput: image.videoOutput
        )
        
        self.mediaURL = url
        self.playerCoordinator = player
        self.imageCoordinator = image
    }
    
    public init(url: URL) {
        let imageCoordinator = PlaybackImageCoordinator(
            url: url
        )
        let playerCoordinator = PlaybackPlayerCoordinator(
            url: url,
            videoOutput: imageCoordinator.videoOutput
        )
        // Now assign to stored properties
        self.imageCoordinator = imageCoordinator
        self.playerCoordinator = playerCoordinator
        
        self.mediaURL = url
        self.imageCoordinator.assign(to: playerCoordinator.player)
        self.imageCoordinator.startRendering()
        self.playerCoordinator.onClearCurrentFrame = { [weak self] in
            guard let self else { return }
            self.imageCoordinator.clearCurrentFrame()
        }
        hasLoaded = true
    }
    
    public func load(url: URL) {
        self.mediaURL = url
        
        let imageCoordinator = PlaybackImageCoordinator(url: url)
        let playerCoordinator = PlaybackPlayerCoordinator(
            url: url,
            videoOutput: imageCoordinator.videoOutput
        )
        
        self.imageCoordinator = imageCoordinator
        self.playerCoordinator = playerCoordinator
        
        imageCoordinator.assign(to: playerCoordinator.player)
        imageCoordinator.startRendering()
        hasLoaded = true
    }
    
    public func play() {
        playerCoordinator.play()
    }
    public func pause() {
        playerCoordinator.pause()
    }
    
    public func previewSeek(to time: CMTime) {
        previewSeekGeneration &+= 1
        let generation = previewSeekGeneration
        
        playerCoordinator.previewSeek(to: time) { [weak self] finished in
            guard finished, let self else { return }
            
            Task { @MainActor in
                guard generation == self.previewSeekGeneration else { return }
                
                self.imageCoordinator.refreshCurrentFrame(
                    at: self.playerCoordinator.player.currentTime(),
                    fallbackAsset: self.playerCoordinator.player.currentItem?.asset
                )
            }
        }
    }
    
    public func seek(to time: CMTime) {
        previewSeekGeneration &+= 1
        
        playerCoordinator.seek(to: time) { [weak self] finished in
            guard finished, let self else { return }

            Task { @MainActor in
                self.imageCoordinator.refreshCurrentFrame(
                    at: self.playerCoordinator.player.currentTime(),
                    fallbackAsset: self.playerCoordinator.player.currentItem?.asset
                )
            }
        }
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
