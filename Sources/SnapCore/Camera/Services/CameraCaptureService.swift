//
//  CameraCaptureService.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

public actor CameraCaptureService: CameraCaptureProviding {

    internal var session: AVCaptureSession?
    internal let movieOutput = AVCaptureMovieFileOutput()
    internal let videoOutput = AVCaptureVideoDataOutput()
    internal let frameHandler = PixelBufferFrameHandler()
    internal var onFaceBoxes: (([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void)?

    internal var multiFaceRecognitionHandler: MultiFaceRecognitionHandler?
    
    @MainActor
    private let recordingDelegate = RecordingDelegate()
    
    public init() {
    }
    
    func startRecording(to url: URL) {
        guard session != nil else { return }
        guard !movieOutput.isRecording else { return }
        
        Task { @MainActor in
            movieOutput.startRecording(to: url, recordingDelegate: recordingDelegate)
        }
    }
    
    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
}
