//
//  CameraCaptureService+startCamera.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//
import AVFoundation

extension CameraCaptureService {
    public func startCameraWithBodyTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace = .sRGB,
        optimize: Bool
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

        try setupBodyTrackingOutputs(
            with: device,
            for: cameraPosition,
            in: session,
            optimize: optimize
        )

        session.commitConfiguration()
        session.startRunning()

        self.session = session
        self.cameraState = .cameraStarted
    }
}

extension CameraCaptureService {
    public func startCameraWithBody3DTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace = .sRGB,
        optimize: Bool
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

        try setupBody3DTrackingOutputs(
            with: device,
            for: cameraPosition,
            in: session,
            optimize: optimize
        )

        session.commitConfiguration()
        session.startRunning()

        self.session = session
        self.cameraState = .cameraStarted
    }
}

extension CameraCaptureService {
    public func startCameraWithFaceTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace = .sRGB,
        optimize: Bool
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

        try setupFaceTrackingOutputs(
            with: device,
            for: cameraPosition,
            in: session,
            optimize: optimize
        )

        session.commitConfiguration()
        session.startRunning()

        self.session = session
        self.cameraState = .cameraStarted
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
            with: device,
            for: cameraPosition,
            in: session
        )

        session.commitConfiguration()
        session.startRunning()

        self.session = session
        self.cameraState = .cameraStarted
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
        with device: AVCaptureDevice,
        for position: CameraPosition,
        in session: AVCaptureSession
    ) throws {
        try attachFrameOutput(to: session)
        configureVideoConnection(with: device, for: position)
    }

    /**
     * Internal Public Facing API For Configuring Output with Body Tracking activated
     */
    private func setupBodyTrackingOutputs(
        with device: AVCaptureDevice,
        for position: CameraPosition,
        in session: AVCaptureSession,
        optimize: Bool
    ) throws {
        try attachBodyTrackingOutput(
            in: session,
            optimize: optimize,
            position: position
        )
        configureVideoConnection(with: device, for: position)
    }

    /**
     * Internal Public Facing API For Configuring Output with Face Tracking activated
     */
    private func setupFaceTrackingOutputs(
        with device: AVCaptureDevice,
        for position: CameraPosition,
        in session: AVCaptureSession,
        optimize: Bool
    ) throws {
        try attachFaceTrackingOutput(
            in: session,
            optimize: optimize,
            position: position
        )
        configureVideoConnection(with: device, for: position)
    }

    /**
     * Internal Public Facing API For Configuring Output with Body 3D Tracking activated
     */
    private func setupBody3DTrackingOutputs(
        with device: AVCaptureDevice,
        for position: CameraPosition,
        in session: AVCaptureSession,
        optimize: Bool
    ) throws {
        try attachBody3DTrackingOutput(
            in: session,
            optimize: optimize,
            position: position
        )
        configureVideoConnection(with: device, for: position)
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

    private func attachBodyTrackingOutput(
        in session: AVCaptureSession,
        optimize: Bool,
        position: CameraPosition
    ) throws {
        let handler = BodyRecognitionHandler(
            optimize,
            orientation: position == .front ? .upMirrored : .right
        )

        if let onBodyResult {
            handler.setOnBodyResult(onBodyResult)
        }

        self.bodyRecognitionHandler = handler

        try addVideoOutput(
            in: session,
            handler: handler
        )
    }

    /**
     * for the FaceTracking, this is the live feel that hits
     * the frame ahndler delegate
     */
    private func attachFaceTrackingOutput(
        in session: AVCaptureSession,
        optimize: Bool,
        position: CameraPosition
    ) throws {
        let handler = MultiFaceRecognitionHandler(
            optimize,
            orientation: position == .front ? .upMirrored : .right
        )
        if let onFaceBoxes {
            handler.setOnFaceBoxes(onFaceBoxes)
        }

        self.multiFaceRecognitionHandler = handler

        try addVideoOutput(
            in: session,
            handler: handler
        )
    }

    private func attachBody3DTrackingOutput(
        in session: AVCaptureSession,
        optimize: Bool,
        position: CameraPosition
    ) throws {
        let handler = Body3DRecognitionHandler(
            optimize,
            orientation: position == .front ? .upMirrored : .right
        )

        if let onBody3DResult {
            handler.setOnBody3DResult(onBody3DResult)
        }

        self.body3DRecognitionHandler = handler

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
    private func configureVideoConnection(
        with device: AVCaptureDevice,
        for position: CameraPosition
    ) {
        guard let connection = videoOutput.connection(with: .video) else { return }

        rotationObservation = nil
        let coordinator = AVCaptureDevice.RotationCoordinator(
            device: device,
            previewLayer: nil
        )
        rotationCoordinator = coordinator

        let rotationTarget = VideoRotationTarget(connection: connection)
        rotationTarget.apply(coordinator.videoRotationAngleForHorizonLevelCapture)

        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { _, change in
            guard let angle = change.newValue else { return }
            rotationTarget.apply(angle)
        }

        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = position == .front
        }
    }
}
