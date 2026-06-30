//
//  ScreenCaptureProviding.swift
//  SnapCore
//
//  Created by Aryan Rogye on 5/7/26.
//

#if os(iOS)

import ReplayKit

public protocol ScreenCaptureProviding {
    var onScreenCapture: ((CMSampleBuffer, RPSampleBufferType) -> Void)? { get set }
    
    func startCapture()
    
}

#endif
