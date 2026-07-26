// CameraCaptureService+setOnBody3DResult.swift
// Services

import AVFoundation

extension CameraCaptureService {
    public func setOnBody3DResult(
        _ handler: @escaping ([BodyPose3D], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async {
        self.onBody3DResult = handler
    }
}
