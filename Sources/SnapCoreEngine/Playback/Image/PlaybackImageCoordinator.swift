//
//  PlaybackImageCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

#if os(macOS)
import AppKit
import AVFoundation
import CoreImage

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
    var cursorMotionState = CursorMotionState()
    public var cursorShadowConfig = CursorShadowConfig()
    
    public var cursorMotionSensitivity: CGFloat = 0.5
    
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
    
    /// Cursor
    public var cursorConfig = CursorConfig(
        size: CGSize(width: 16, height: 16),
        lineWidth: 2
    )
    
    let imageColorProcessor = ImageColorProcessor()
    let imageContrastBooster = ImageContrastBooster()
    let imageSharpener = ImageSharpener()
    let cursorSticher = CursorSticher()
    
    var cursorTexture: MTLTexture?
    
    init(recordingInfo: RecordingInfo) {
        self.recordingInfo = recordingInfo
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        
        cursorConfig = CursorConfig(
            size: CGSize(width: 16, height: 16),
            scale: max(1.0, CGFloat(CursorSizeHelper.cursorScale())),
            lineWidth: 2
        )
        
        self.assignCursorImage()
        self.observeValues()
        self.observeCursor()
    }
    
    public func assignCursorImage() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            if let cursor = CursorShape.makeCursorCGImage(
                config: cursorConfig
            ) {
                do {
                    cursorTexture = try MetalHelpers.getImageTexture(from: cursor)
                } catch {
                    print("Error Creating Cursor Texture: \(error.localizedDescription)")
                }
            }
        }
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
            if let point = f.mouse {
                if let previous = cursorMotionState.previousPoint {
                    self.cursorMotionState.dx = CGFloat(point.x - previous.x)
                    self.cursorMotionState.dy = CGFloat(point.y - previous.y)
                    // compute target angle from dx
                    let targetAngle = Float(cursorMotionState.dx) * Float(cursorMotionSensitivity)
                    let current = Float(cursorMotionState.currentAngle)
                    cursorMotionState.currentAngle = CGFloat(current + (targetAngle - current) * 0.2)
                }
                self.cursorMotionState.previousPoint = point
            }
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
    
    public func observeCursor() {
        withObservationTracking {
            _ = self.cursorConfig.innerColor
            _ = self.cursorConfig.outerColor
            _ = self.cursorConfig.scale
            _ = self.cursorConfig.size
            _ = self.cursorConfig.lineWidth
            _ = self.cursorConfig.distanceFromBottomScale
            _ = self.cursorConfig.distanceFromCenterScale
            _ = self.cursorConfig.distanceFromHorizontal
            _ = self.cursorConfig.wingDistanceDown
            _ = self.cursorConfig.roundness
            
            /// Shadow Configs
            _ = self.cursorShadowConfig.cursorShadowOpacity
            _ = self.cursorShadowConfig.cursorShadowSharpOpacity
            _ = self.cursorShadowConfig.cursorShadowX
            _ = self.cursorShadowConfig.cursorShadowY
            _ = self.cursorShadowConfig.cursorShadowSharpX
            _ = self.cursorShadowConfig.cursorShadowSharpY
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                assignCursorImage()
                if let originalCurrentFrame {
                    do {
                        try processImage(cgImage: originalCurrentFrame)
                    } catch {
                        print("Error Processing Image in Observation: \(error.localizedDescription)")
                    }
                }
                self.observeCursor()
            }
        }
    }
    
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
                    do {
                        try processImage(cgImage: originalCurrentFrame)
                    } catch {
                        print("Error Processing Image in Observation: \(error.localizedDescription)")
                    }
                }
                
                observeValues()
            }
        }
    }
}
#endif
