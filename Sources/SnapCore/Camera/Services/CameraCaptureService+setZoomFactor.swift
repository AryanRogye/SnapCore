//
//  CameraCaptureService+setZoomFactor.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/21/26.
//

import AVFoundation

extension CameraCaptureService {
    public func setZoomFactor(_ factor: CGFloat, rate: Float = 4.0) async {
        guard let device = (session?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
#if os(iOS)
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(factor, device.maxAvailableVideoZoomFactor))
            device.ramp(toVideoZoomFactor: clamped, withRate: rate)
            device.unlockForConfiguration()
        } catch {
            return
        }
#endif
    }
    public func setZoomFactorInstant(_ factor: CGFloat) async {
        guard let device = (session?.inputs.first as? AVCaptureDeviceInput)?.device else { return }
        
#if os(iOS)
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor,
                              min(factor, device.maxAvailableVideoZoomFactor))
            
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            return
        }
#endif
    }
}
