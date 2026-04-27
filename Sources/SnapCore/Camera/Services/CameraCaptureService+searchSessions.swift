//
//  CameraCaptureService+searchSessions.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/21/26.
//

import AVFoundation

extension CameraCaptureService {
    
    public func searchSessions() async -> [AVCaptureDevice] {
        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
            ],
            mediaType: .video,
            position: .unspecified
        )
        #else
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInDualCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        #endif
        
        return discoverySession.devices
    }
}
