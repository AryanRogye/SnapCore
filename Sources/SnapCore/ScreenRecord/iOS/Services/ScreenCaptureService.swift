//
//  ScreenCaptureService.swift
//  SnapCore
//
//  Created by Aryan Rogye on 5/7/26.
//

#if os(iOS)

import ReplayKit
import CoreMedia

public final class ScreenCaptureService: ScreenCaptureProviding {
    
    private let recorder = RPScreenRecorder.shared()
    
    public var onScreenCapture: ((CMSampleBuffer, RPSampleBufferType) -> Void)?
    public var onError: ((Error) -> Void)?
    
    public init() {}
    
    public func startCapture() {
        guard recorder.isAvailable else {
            return
        }
        
        recorder.startCapture { [weak self] sampleBuffer, type, error in
            if let error {
                self?.onError?(error)
                return
            }
            
            self?.onScreenCapture?(sampleBuffer, type)
            
        } completionHandler: { [weak self] error in
            if let error {
                self?.onError?(error)
            }
        }
    }
    
    public func stopCapture() {
        recorder.stopCapture { [weak self] error in
            if let error {
                self?.onError?(error)
            }
        }
    }
}

#endif
