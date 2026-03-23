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
    internal var fps: FPS = .fps120
    internal var cachedFilter: SCContentFilter?
    internal var lastBackingScaleFactorUsed: CGFloat = 2.0
    internal var pendingRecordingOutputURL: URL?
    internal var recordingOutputStorage: AnyObject?
    internal var recordingOutputErrorMessage: String?

    internal let videoQueue = DispatchQueue(label: "video", qos: .userInteractive)
    internal let audioQueue = DispatchQueue(label: "audio", qos: .userInteractive)
    
    internal var screenFrameTask: Task<Void, Never>?
    internal var audioFrameTask: Task<Void, Never>?
    
    public var onScreenFrame: ScreenFrameHandler?
    public var onAudioFrame: ScreenFrameHandler?

    
    public override init() {
        super.init()
    }
    
    // MARK: - Getters
    public func getCachedFilter() -> SCContentFilter? {
        cachedFilter
    }
    
    public func getLastScaleFactorUsed() -> CGFloat {
        return lastBackingScaleFactorUsed
    }
}

#endif
