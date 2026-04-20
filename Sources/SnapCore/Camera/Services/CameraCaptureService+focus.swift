//
//  CameraCaptureService+focus.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

extension CameraCaptureService {
    /**
     * Function Focuses At The Point
     */
    public func focus(
        at point: CGPoint,
        in viewSize: CGSize
    ) async {
        guard let device = (session?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
        let focusPoint = CGPoint(x: point.y / viewSize.height, y: 1 - point.x / viewSize.width)
        
        try? device.lockForConfiguration()
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()
    }
    
}
