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
    
    let mediaURL: URL
    
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

    public init(url: URL) {
        mediaURL = url
        
        let imageCoordinator = PlaybackImageCoordinator(
            url: mediaURL
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
        self.playerCoordinator.onClearCurrentFrame = { [weak self] in
            guard let self else { return }
            self.imageCoordinator.clearCurrentFrame()
        }
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
