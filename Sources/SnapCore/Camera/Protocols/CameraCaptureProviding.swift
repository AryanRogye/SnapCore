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
     * Function To Know if Camera was Authorized Or Not
     */
    func isAuthorized() async -> Bool
    
    /**
     * Function To get the current capture session
     */
    func getSession() async -> AVCaptureSession?
    
    /**
     * Function starts the camera
     */
    func startCamera(
        _ type: AVCaptureDevice.DeviceType,
        cameraPosition: CameraPosition
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
}
