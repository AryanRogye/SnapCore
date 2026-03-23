//
//  RecordingModels.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

import AVFoundation
import AppKit
import ScreenCaptureKit

@Observable
@MainActor
public final class RecordingInfo {
    
    public var url: URL?
    public var lastImage: CGImage?
    public var frames: [FrameInfo] = []
    
    public var displayWidth: Int?
    public var displayHeight: Int?
    public var frame: CGRect?
    
    public init() {
    }
    
    public func clear() {
        self.frames.removeAll()
        self.url = nil
    }
    
    public func setURL(_ url: URL) {
        self.url = url
    }
    
    public func append(_ frame: FrameInfo) {
        frames.append(frame)
    }
    
    func setLastImage(_ image: CGImage) {
        self.lastImage = image
    }
    
    public func getURL() -> URL? {
        self.url
    }

    public var recordedURL: URL? {
        url
    }
    
    public var latestPreviewImage: CGImage? {
        lastImage
    }
}

public struct FrameInfo {
    public var time: CMTime
    public var mouse: CGPoint?
    public var leftMouseDown: Bool
    public var rightMouseDown: Bool
    
    public init(time: CMTime, mouse: CGPoint? = nil, leftMouseDown: Bool, rightMouseDown: Bool) {
        self.time = time
        self.mouse = mouse
        self.leftMouseDown = leftMouseDown
        self.rightMouseDown = rightMouseDown
    }
}
