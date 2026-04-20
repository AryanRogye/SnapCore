//
//  CameraCaptureService+startCamera.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

extension CameraCaptureService {
    /**
     * Function starts the camera
     */
    public func startCamera(
        _ type: AVCaptureDevice.DeviceType,
        cameraPosition: CameraPosition
    ) async throws {
        await stopCamera()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(
            type,
            for: .video,
            position: AVCaptureDevice.Position(rawValue: cameraPosition.rawValue) ?? .front
        ) else {
            throw CameraError.cantConfigure
        }
        
        let input = try AVCaptureDeviceInput(device: device)
        
        guard session.canAddInput(input) else {
            throw CameraError.cantConfigure
        }
        session.addInput(input)
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            frameHandler,
            queue: DispatchQueue(label: "camera.pixel-buffer.frames")
        )
        
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.cantConfigure
        }
        session.addOutput(videoOutput)
        
        guard session.canAddOutput(movieOutput) else {
            throw CameraError.cantConfigure
        }
        session.addOutput(movieOutput)
        
        if let connection = videoOutput.connection(with: .video) {
            let angle: CGFloat = cameraPosition == .front ? 0 : 90
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if cameraPosition == .front && connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        session.commitConfiguration()
        session.startRunning()
        
        self.session = session
    }
}
