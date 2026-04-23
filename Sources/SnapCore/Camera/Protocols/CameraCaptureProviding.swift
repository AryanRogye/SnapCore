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
     * Function sets what happens when capture starts with face tracking
     */
    func setOnPersonMask(
        _ handler: @escaping ((CVPixelBuffer) -> Void)
    ) async
    
    /**
     * Function sets what happens when capture starts with face tracking
     */
    func setOnFaceBoxes(
        _ handler: @escaping ([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) async
    
    /**
     * Function To Know if Camera was Authorized Or Not
     */
    func isAuthorized() async -> Bool
    
    /**
     * Function To get the current capture session
     */
    func getSession() async -> AVCaptureSession?
    
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
        optimize: Bool,
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
