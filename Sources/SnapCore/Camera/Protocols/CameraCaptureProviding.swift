//
//  CameraCaptureProviding.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

public protocol CameraCaptureProviding {
    /**
     * Function sets what happens when capture starts
     */
    func setOnPixelBuffer(
        _ handler: @escaping (CVPixelBuffer) -> Void
    ) async

    /**
     * Function sets what happens when capture starts with body tracking
     */
    func setOnBodyResult(
        _ handler: @escaping ([BodyPose], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async

    /**
     * Function sets what happens when capture starts with body 3D tracking
     */
    func setOnBody3DResult(
        _ handler: @escaping ([BodyPose3D], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async

    /**
     * Function sets what happens when capture starts with face tracking
     */
    func setOnFaceBoxes(
        _ handler: @escaping ([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async

    /**
     * Function sets what happens when capture starts with hand tracking
     */
    func setOnHandResult(
        _ handler: @escaping ([HandPose], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async

    /**
     * Function sets what happens when capture starts with detailed face tracking
     */
    func setOnDetailedFaceResult(
        _ handler: @escaping ([DetailedFace], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async

    /**
     * Function returns if the camera is stopped or running
     */
    func getCameraState() async -> CameraState

    /**
     * Function To Know if Camera was Authorized Or Not
     */
    func isAuthorized() async -> Bool

    /**
     * Function To get the current capture session
     */
    func getSession() async -> AVCaptureSession?

    /**
     * Function starts the camera with body, face, hand, and/or 3D tracking on
     * this is the replacement to the old custom function that we had, use this
     * instead of the old function, it also removes the need to call any other
     * start functions
     */
    func startMultiRecognitionTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool,
        recognitionConfiguration: [MultiRecognitionConfiguration]
    ) async throws

    /**
     * Function starts the camera with
     * body tracking on, this means if anyone
     * sets the handlers then they can get the bodies
     * routed through there
     */
    func startCameraWithBodyTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool
    ) async throws

    /**
     * Function starts the camera with
     * face tracking on, this means if anyone
     * sets the handlers then they can get the faces
     * routed through there
     */
    func startCameraWithFaceTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool
    ) async throws

    /**
     * Function starts the camera with hand tracking on
     */
    func startCameraWithHandTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool
    ) async throws

    /**
     * Function starts the camera with detailed face landmark tracking on
     */
    func startCameraWithDetailedFaceTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool
    ) async throws

    /**
     * Function starts the camera with
     * body 3D tracking on, this means if anyone
     * sets the handlers then they can get the 3D body poses
     * routed through there
     */
    func startCameraWithBody3DTracking(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace,
        optimize: Bool,
        trackingMovement: Bool
    ) async throws

    /**
     * Function starts the camera
     */
    func startCamera(
        with device: AVCaptureDevice,
        fps: CameraFPS,
        cameraPosition: CameraPosition,
        colorSpace: CameraColorSpace
    ) async throws

    /**
     * Function stops the camera
     */
    func stopCamera() async

    /**
     * Function Focuses At The Point
     */
    func focus(
        at point: CGPoint,
        in viewSize: CGSize
    ) async

    /**
     * Sets the zoom factor for the camera
     */
    func setZoomFactor(
        _ factor: CGFloat,
        rate: Float
    ) async

    /**
     * Function sets the zoom with no animation
     */
    func setZoomFactorInstant(
        _ factor: CGFloat
    ) async

    /**
     * Function returns the devices available with the session
     */
    func searchSessions() async -> [AVCaptureDevice]
}
