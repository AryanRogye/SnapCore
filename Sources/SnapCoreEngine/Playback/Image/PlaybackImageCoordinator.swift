//
//  PlaybackImageCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

import AppKit
import AVFoundation
import CoreImage

public struct CurrentMouseInfo: Equatable {
    public var point: CGPoint?
    public var isLeftClick: Bool
    public var isRightClick: Bool
}

/// boosting contrast

@Observable
public final class PlaybackImageCoordinator {
    let recordingInfo: RecordingInfo
    var videoOutput: AVPlayerItemVideoOutput
    
    public var currentFrame: CGImage?
    public var originalCurrentFrame: CGImage?
    public var currentSharpenedFrame: CGImage?
    public var currentContrastedFrame: CGImage?
    public var currentFrameColor: NSColor?
    
    private var player: AVPlayer?
    
    internal let ciContext = CIContext()
    private var displayLink: CADisplayLink?
    var currentMouse: CurrentMouseInfo?
    
    var currentTime: Float64 = 0
    var progress: Double = 0
    
    /// Sharpness
    public var isAdjustingSharpness = false
    public var sharpness: CGFloat = 2.0
    public var sharpnessSideBySide: Bool = false
    
    /// Contrast
    public var isAdjustingContrast = false
    public var contrast: CGFloat = 1.0
    public var contrastSideBySide: Bool = false
    
    let imageProcessor = ImageProcessor()
    let imageContrastBooster = ImageContrastBooster()
    let imageSharpener = ImageSharpener()
    
    init(recordingInfo: RecordingInfo) {
        self.recordingInfo = recordingInfo
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        self.observeValues()
    }
    
    public func assign(to player: AVPlayer) {
        self.player = player
    }
    
    func startRendering() {
        displayLink?.invalidate()
        displayLink = NSScreen.main?.displayLink(target: self, selector: #selector(renderFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @MainActor
    @objc
    private func renderFrame() {
        guard let item = player?.currentItem else { return }
        let time = item.currentTime()
        let duration = CMTimeGetSeconds(item.duration)
        let elapsed = CMTimeGetSeconds(time)
        
        currentTime = elapsed
        progress = duration > 0 ? elapsed / duration : 0
        
        if let f = getFrameInfo(time) {
            self.currentMouse = CurrentMouseInfo(
                point: f.mouse,
                isLeftClick: f.leftMouseDown,
                isRightClick: f.rightMouseDown
            )
        }
        
        guard videoOutput.hasNewPixelBuffer(forItemTime: time) else { return }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        
        processImage(pixelBuffer: pixelBuffer)
    }
}

// MARK: - Observations
extension PlaybackImageCoordinator {
    /// Function Observes:
    /// Sharpness
    /// Contrast
    public func observeValues() {
        withObservationTracking {
            _ = self.isAdjustingSharpness;
            _ = self.isAdjustingContrast
            _ = self.sharpness
            _ = self.contrast
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if let originalCurrentFrame {
                    processImage(cgImage: originalCurrentFrame)
                }
                
                observeValues()
            }
        }
    }
}
