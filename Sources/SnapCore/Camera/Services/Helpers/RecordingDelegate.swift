//
//  RecordingDelegate.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//


import AVFoundation

final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        print("Finished recording:", outputFileURL)
    }
}
