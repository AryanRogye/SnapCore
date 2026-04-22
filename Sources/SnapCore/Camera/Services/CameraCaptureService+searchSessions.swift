//
//  CameraCaptureService+searchSessions.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/21/26.
//

import AVFoundation

extension CameraCaptureService {
    
    public func searchSessions() async -> [AVCaptureDevice] {
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
        
        return discoverySession.devices
    }
}
