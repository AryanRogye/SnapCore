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
    public var currentSharpenedFrame: CGImage?
    public var currentContrastedFrame: CGImage?
    public var currentFrameColor: NSColor?
    
    private var player: AVPlayer?
    
    private let ciContext = CIContext()
    private var displayLink: CADisplayLink?
    var currentMouse: CurrentMouseInfo?
    
    var currentTime: Float64 = 0
    var progress: Double = 0
    
    public var sharpness: CGFloat = 2.0
    public var sharpnessSideBySide: Bool = false
    
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
    
    @MainActor
    private func getFrameInfo(_ time: CMTime) -> FrameInfo? {
        // Make sure we have frames
        guard let firstFrameTime = recordingInfo.frames.first?.time else { return nil }
        
        // Find the frame where its relative time (absolute - start) matches the player time
        if let frame = recordingInfo.frames.last(where: {
            let relativeFrameTime = CMTimeSubtract($0.time, firstFrameTime)
            return relativeFrameTime <= time
        }) {
            return frame
        }
        
        // Fallback
        return recordingInfo.frames.first
    }
    
    private func processImage(pixelBuffer: CVPixelBuffer) {
        guard let original = getCG(from: pixelBuffer) else { return }
        
        let contrasted = getContrastedImage(original)
        let baseForSharpness = contrasted ?? original
        let sharpened = getSharpenedImage(baseForSharpness)
        
        updateDisplayedFrames(
            original: original,
            contrasted: contrasted,
            sharpened: sharpened,
            baseForSharpness: baseForSharpness
        )
        
        currentFrameColor = imageProcessor.getDominantColor(from: original)
    }
    
    private func getContrastedImage(_ image: CGImage) -> CGImage? {
        do {
            return try imageContrastBooster.boostContrast(for: image, factor: Float(contrast))
        } catch {
            print("Error applying contrast: \(error)")
            return nil
        }
    }
    
    private func getSharpenedImage(_ image: CGImage) -> CGImage? {
        do {
            return try imageSharpener.sharpen(image, sharpness: Float(sharpness))
        } catch {
            print("Error sharpening image: \(error)")
            return nil
        }
    }
    
    private func updateDisplayedFrames(
        original: CGImage,
        contrasted: CGImage?,
        sharpened: CGImage?,
        baseForSharpness: CGImage
    ) {
        if contrastSideBySide {
            currentContrastedFrame = contrasted
        } else {
            currentContrastedFrame = nil
        }
        
        if sharpnessSideBySide {
            currentFrame = baseForSharpness
            currentSharpenedFrame = sharpened
        } else {
            currentSharpenedFrame = nil
            currentFrame = sharpened ?? baseForSharpness
        }
        
        if !contrastSideBySide && sharpened == nil && contrasted == nil {
            currentFrame = original
        }
    }
    
    private func getCG(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}
