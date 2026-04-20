//
//  CameraCaptureService+getSession.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

extension CameraCaptureService {
    /**
     * Function To get the current capture session
     */
    public func getSession() async -> AVCaptureSession? {
        return session
    }
}
