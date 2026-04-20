//
//  PixelBufferFrameHandler.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

final class PixelBufferFrameHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var onPixelBuffer: ((CVPixelBuffer) -> Void)?
    
    func setOnPixelBuffer(_ handler: @escaping (CVPixelBuffer) -> Void) {
        self.onPixelBuffer = handler
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onPixelBuffer?(pixelBuffer)
    }
}
