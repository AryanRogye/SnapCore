// CameraCaptureService+setOnBodyResult.swift
// Services
//
// Created by Aryan Rogye on 7/6/26.
//

import AVFoundation

extension CameraCaptureService {
    public func setOnBodyResult(
        _ handler: @escaping ([BodyPose], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async {
        self.onBodyResult = handler
    }
}
