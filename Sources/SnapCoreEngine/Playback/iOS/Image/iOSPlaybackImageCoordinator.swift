//
//  PlaybackImageCoordinator.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/31/26.
//

#if os(iOS)

import AVFoundation
import UIKit

@Observable
public final class PlaybackImageCoordinator {
    private let mediaURL : URL
    /// both iOS and macOS player's need this so must remain public
    private(set) var videoOutput: AVPlayerItemVideoOutput
    
    private var displayLink: CADisplayLink?
    private var player: AVPlayer?
    internal let ciContext = CIContext()

    var currentTime: Float64 = 0
    var progress: Double = 0
    
    public var currentFrame: CGImage?
    public var originalCurrentFrame: CGImage?
    public var currentSharpenedFrame: CGImage?
    public var currentContrastedFrame: CGImage?
    public var currentLanczosFrame: CGImage?
    public var currentFrameColor: UIColor?
    
    /// Sharpness
    public var isAdjustingSharpness = false
    public var sharpness: CGFloat = 2.0
    
    /// Contrast
    public var isAdjustingContrast = false
    public var contrast: CGFloat = 1.0
    
    /// Lanczos
    public var isAdjustingLanczosScale = false
    public var lanczosScale: CGFloat = 1.0
    public var kernelSize: CGFloat = 3.0
    
    let imageProcessor = ImageProcessor()
    let frameCache = FrameCache()
    
    init(url: URL) {
        self.mediaURL = url
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        
        //        self.observeValues()
        //        self.observeCursor()
    }
    
    public func assign(to player: AVPlayer) {
        self.player = player
    }
    
    func startRendering() {
        displayLink?.invalidate()
        displayLink = UIScreen.main.displayLink(withTarget: self, selector: #selector(renderFrame))
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
        
        guard videoOutput.hasNewPixelBuffer(forItemTime: time) else { return }
        guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        
        processImage(pixelBuffer: pixelBuffer)
    }
    
    /// we can give this to other closures so that they can close it
    public func clearCurrentFrame() {
        currentFrame = nil
        originalCurrentFrame = nil
        currentSharpenedFrame = nil
        currentContrastedFrame = nil
        currentLanczosFrame = nil
        currentFrameColor = nil
    }
}

#endif
