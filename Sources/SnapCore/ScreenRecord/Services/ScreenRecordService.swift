//
//  ScreenRecordService.swift
//  SnapCore
//

#if os(macOS)

import AppKit
import ScreenCaptureKit

@MainActor
public final class ScreenRecordService: NSObject, ScreenRecordProviding {
    
    internal var stream: SCStream?
    internal var streamOutput: StreamOutput?
    internal var showsCursor: Bool = true
    internal var capturesAudio: Bool = true
    internal var scale: VideoScale = .normal
    internal var cachedFilter: SCContentFilter?
    internal var lastBackingScaleFactorUsed: CGFloat = 2.0
    internal var pendingRecordingOutputURL: URL?
    internal var recordingOutputStorage: AnyObject?
    internal var recordingOutputErrorMessage: String?

    internal let videoQueue = DispatchQueue(label: "video", qos: .userInteractive)
    internal let audioQueue = DispatchQueue(label: "audio", qos: .userInteractive)
    
    private var screenFrameTask: Task<Void, Never>?
    private var audioFrameTask: Task<Void, Never>?
    
    public var onScreenFrame: ScreenFrameHandler?
    public var onAudioFrame: ScreenFrameHandler?

    
    public override init() {
        super.init()
    }
    
    public func getCachedFilter() -> SCContentFilter? {
        cachedFilter
    }
    
    public func getLastScaleFactorUsed() -> CGFloat {
        return lastBackingScaleFactorUsed
    }
    
    public func prepareRecordingOutput(url: URL) {
        pendingRecordingOutputURL = url
        recordingOutputErrorMessage = nil
    }
    
    public func getRecordingOutputErrorMessage() -> String? {
        recordingOutputErrorMessage
    }
    
    internal func attachOutput(_ output: StreamOutput) {
        streamOutput = output
        
        screenFrameTask = Task { [weak self] in
            for await frame in output.screenFrames {
                await self?.onScreenFrame?(frame)
            }
        }
        
        audioFrameTask = Task { [weak self] in
            for await frame in output.audioFrames {
                await self?.onAudioFrame?(frame)
            }
        }
    }
    
    internal func calculateWidthAndHeight(display: SCDisplay) -> (width: Int, height: Int) {
        let pointWidth = Int(display.frame.width.rounded(.down))
        let pointHeight = Int(display.frame.height.rounded(.down))
        
        let matchingScreen = NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return screenNumber == display.displayID
        }
        
        let scaleFactor = matchingScreen?.backingScaleFactor ?? 2.0
        lastBackingScaleFactorUsed = scaleFactor
        
        let aspectRatio = CGFloat(pointWidth) / CGFloat(pointHeight)
        switch scale {
        case .normal, .medium, .high, .ultra:
            let height = scale.value
            let width = Int(CGFloat(height) * aspectRatio)
            return (width, height)
        case .native:
            let nativeWidth = Int(CGFloat(pointWidth) * scaleFactor)
            let nativeHeight = Int(CGFloat(pointHeight) * scaleFactor)
            return (nativeWidth, nativeHeight)
        }
    }
    
    internal func detachOutput() {
        screenFrameTask?.cancel()
        audioFrameTask?.cancel()
        screenFrameTask = nil
        audioFrameTask = nil
        streamOutput = nil
    }

}

extension ScreenRecordService: SCRecordingOutputDelegate {
    nonisolated public func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
    }
    
    nonisolated public func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in
            self?.recordingOutputErrorMessage = error.localizedDescription
        }
    }
    
    nonisolated public func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
    }
}


#endif
