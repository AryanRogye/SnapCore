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
    
    internal let videoQueue = DispatchQueue(label: "video", qos: .userInteractive)
    internal let audioQueue = DispatchQueue(label: "audio", qos: .userInteractive)
    
    public var onScreenFrame: ScreenFrameHandler?
    public var onAudioFrame: ScreenFrameHandler?
    
    public override init() {
        super.init()
    }    
}


#endif
