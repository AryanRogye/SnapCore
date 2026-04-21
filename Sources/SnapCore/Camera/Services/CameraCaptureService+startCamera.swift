//
//  CameraCaptureService+startCamera.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//
import AVFoundation

extension CameraCaptureService {
    
    public func startCamera(
        _ type: AVCaptureDevice.DeviceType,
        fps: CameraFPS,
        cameraPosition: CameraPosition
    ) async throws {
        await stopCamera()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        /// We configure out input for the camera device type the user wants
        /// also if its facing front or back
        try configureInput(for: type, fps: fps, position: cameraPosition, in: session)
        
        try configureOutputs(for: cameraPosition, in: session)
        
        session.commitConfiguration()
        session.startRunning()
        
        self.session = session
    }
    
    // MARK: - Private Helpers
    
    private func configureInput(
        for type: AVCaptureDevice.DeviceType,
        fps: CameraFPS,
        position: CameraPosition,
        in session: AVCaptureSession
    ) throws {
        guard let device : AVCaptureDevice = AVCaptureDevice.default(
            type,
            for: .video,
            position: AVCaptureDevice.Position(rawValue: position.rawValue) ?? .front
        ) else {
            throw CameraError.cantConfigure
        }
        
        try configureFPS(for: device, fps: fps)
        
        let input = try AVCaptureDeviceInput(device: device)
        
        guard session.canAddInput(input) else {
            throw CameraError.cantConfigure
        }
        session.addInput(input)
    }
    
    private func configureFPS(
        for device: AVCaptureDevice,
        fps: CameraFPS
    ) throws {
        
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        let fps : Double = fps.rawValue
        
        let bestFormat = device.formats
            .filter { format in
                // Keep only formats that support our target FPS
                format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= fps }
            }
            .sorted { f1, f2 in
                // Sort by pixel count (Width * Height) descending
                let dim1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription)
                let dim2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription)
                return (dim1.width * dim1.height) > (dim2.width * dim2.height)
            }
            .first
        
        if let bestFormat {
            device.activeFormat = bestFormat
            
            if let range = bestFormat.videoSupportedFrameRateRanges.first(where: { $0.maxFrameRate >= fps }) {
                device.activeVideoMinFrameDuration = range.minFrameDuration
                /// Using the minDuration forces a max speed
                device.activeVideoMaxFrameDuration = range.minFrameDuration
            }
        }
        
    }
    
    private func configureOutputs(
        for position: CameraPosition,
        in session: AVCaptureSession
    ) throws {
        try configureVideoOutput(in: session)
        configureVideoConnection(for: position)
    }
    
    /**
     * Sets up the PixelBuffer Stream. this is basically the live feed that hits the
     * frame handler delegate
     *
     * so every frame the camera captures flows through here, its what we use for real
     * time preview
     */
    private func configureVideoOutput(in session: AVCaptureSession) throws {
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
    }
    
    /**
     * Sets up the rotating/mirroring on the connection between the camera and the video output
     * this is a post setup step that only runs after both output and session are wired
     */
    private func configureVideoConnection(for position: CameraPosition) {
        guard let connection = videoOutput.connection(with: .video) else { return }
        
        let angle: CGFloat = position == .front ? 0 : 90
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        
        if position == .front && connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }
    }
    
//    private func configureMovieOutput(in session: AVCaptureSession) throws {
//        guard session.canAddOutput(movieOutput) else {
//            throw CameraError.cantConfigure
//        }
//        session.addOutput(movieOutput)
//    }
}
