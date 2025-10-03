//
//  ScreenRecordService.swift
//  SnapCore
//

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
    
    public var onScreenFrame: ((CMSampleBuffer) -> Void)?
    public var onAudioFrame: ((CMSampleBuffer) -> Void)?
    
    public override init() {
        super.init()
    }    
}
