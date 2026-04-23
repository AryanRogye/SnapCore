//
//  CameraCaptureService+startCamera.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//
import AVFoundation

extension CameraCaptureService {
    public func startCameraWithFaceTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace = .sRGB,
        optimize: Bool,
    ) async throws {
        await stopCamera()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        try configureInput(
            with: device,
            for: device.deviceType,
            fps: fps,
            position: cameraPosition,
            colorSpace: colorSpace,
            in: session
        )
        
        await try setupFaceTrackingOutputs(
            for: cameraPosition,
            in: session,
            optimize: optimize,
        )
        
        session.commitConfiguration()
        session.startRunning()
        
        self.session = session
    }
}

extension CameraCaptureService {
    public func startCamera(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace = .sRGB
    ) async throws {
        await stopCamera()
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        /// We configure out input for the camera device type the user wants
        /// also if its facing front or back
        try configureInput(
            with: device,
            for: device.deviceType,
            fps: fps,
            position: cameraPosition,
            colorSpace: colorSpace,
            in: session
        )
        
        try setupStandardOptions(
            for: cameraPosition,
            in: session
        )
        
        session.commitConfiguration()
        session.startRunning()
        
        self.session = session
    }
    
    // MARK: - Private Helpers
}

/**
 * This is the Configuring of the input
 */
extension CameraCaptureService {
    private func configureInput(
        with device: AVCaptureDevice,
        for type: AVCaptureDevice.DeviceType,
        fps: CameraFPS,
        position: CameraPosition,
        colorSpace: CameraColorSpace,
        in session: AVCaptureSession
    ) throws {
        try configureFPS(for: device, fps: fps, colorSpace: colorSpace)
        
        let input = try AVCaptureDeviceInput(device: device)
        
        guard session.canAddInput(input) else {
            throw CameraError.cantConfigure
        }
        session.addInput(input)
    }
    
    private func configureFPS(
        for device: AVCaptureDevice,
        fps: CameraFPS,
        colorSpace: CameraColorSpace
    ) throws {
        let targetFPS = Double(fps.rawValue)
        let targetColorSpace = colorSpace.avColorSpace
        let targetDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS.rounded()))
        
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        func supportsFPS(_ format: AVCaptureDevice.Format) -> Bool {
            format.videoSupportedFrameRateRanges.contains { range in
                range.minFrameRate <= targetFPS && targetFPS <= range.maxFrameRate
            }
        }
        
        func pixelCount(_ format: AVCaptureDevice.Format) -> Int32 {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dims.width * dims.height
        }
        
        // First try: format supports BOTH requested FPS and requested color space
        let bestFormat =
        device.formats
            .filter { format in
                supportsFPS(format) &&
                format.supportedColorSpaces.contains(targetColorSpace)
            }
            .max(by: { pixelCount($0) < pixelCount($1) })
        
        // Fallback: supports FPS, but not requested color space
        ?? device.formats
            .filter { supportsFPS($0) }
            .max(by: { pixelCount($0) < pixelCount($1) })
        
        guard let bestFormat else {
            print("❌ No format supports \(targetFPS) FPS")
            return
        }
        
        device.activeFormat = bestFormat
        
        // Apply color space
        let supportedColorSpaces = bestFormat.supportedColorSpaces
        if supportedColorSpaces.contains(targetColorSpace) {
            device.activeColorSpace = targetColorSpace
        } else if let fallback = supportedColorSpaces.first {
            device.activeColorSpace = fallback
            print("⚠️ \(colorSpace) not supported at \(fps.rawValue) FPS, using \(fallback)")
        } else {
            print("⚠️ No supported color spaces found on selected format")
        }
        
        // Apply exact FPS
        device.activeVideoMinFrameDuration = targetDuration
        device.activeVideoMaxFrameDuration = targetDuration
    }
}

/**
 * Section handles the outputs of the camera
 */
extension CameraCaptureService {
    /**
     * Internal Public Facing API for Configuring Output
     */
    private func setupStandardOptions(
        for position: CameraPosition,
        in session: AVCaptureSession
    ) throws {
        try attachFrameOutput(to: session)
        configureVideoConnection(for: position)
    }
    
    /**
     * Internal Public Facing API For Configuring Output with Face Tracking activated
     */
    private func setupFaceTrackingOutputs(
        for position: CameraPosition,
        in session: AVCaptureSession,
        optimize: Bool,
    ) async throws {
        try await attachFaceTrackingOutput(
            in: session,
            optimize: optimize,
            position: position,
        )
        configureVideoConnection(for: position)
    }
    
    /**
     * Sets up the PixelBuffer Stream. this is basically the live feed that hits the
     * frame handler delegate
     *
     * so every frame the camera captures flows through here, its what we use for real
     * time preview
     */
    private func attachFrameOutput(to session: AVCaptureSession) throws {
        try addVideoOutput(
            in: session,
            handler: frameHandler
        )
    }
    
    /**
     * for the FaceTracking, this is the live feel that hits
     * the frame ahndler delegate
     */
    private func attachFaceTrackingOutput(
        in session: AVCaptureSession,
        optimize: Bool,
        position: CameraPosition,
    ) async throws {
        
        let handler = await MultiFaceRecognitionHandler(
            optimize,
            orientation: position == .front ? .upMirrored : .right
        )
        if let onPersonMask {
            handler.setOnPersonMask(onPersonMask)
        }
        if let onFaceBoxes {
            handler.setOnFaceBoxes(onFaceBoxes)
        }
        
        self.multiFaceRecognitionHandler = handler

        try addVideoOutput(
            in: session,
            handler: handler
        )
    }
    
    /**
     * Main Wrapper for Adding Video Output
     * Sets up the PixelBuffer Stream for whatever handler we may need
     *
     * this is basically the live feed that hits the
     * frame handler delegate
     *
     * so every frame the camera captures flows through here, its what we use for real
     * time preview
     */
    private func addVideoOutput(
        in session: AVCaptureSession,
        handler: AVCaptureVideoDataOutputSampleBufferDelegate
    ) throws {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            handler,
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
}
