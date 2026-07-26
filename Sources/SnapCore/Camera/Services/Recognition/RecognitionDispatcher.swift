//
//  RecognitionDispatcher.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/26/26.
//

import AVFoundation
import Vision

final class RecognitionDispatcher:
    NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    private var handlers: [AVCaptureVideoDataOutputSampleBufferDelegate] = []
    
    func addHandler(
        _ handler: AVCaptureVideoDataOutputSampleBufferDelegate
    ) {
        handlers.append(handler)
    }
    
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        for handler in handlers {
            handler.captureOutput?(
                output,
                didOutput: sampleBuffer,
                from: connection
            )
        }
    }
}
