//
//  MultiFaceRecognitionHandler.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/22/26.
//

import AVFoundation
import Vision

final class MultiFaceRecognitionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, FaceRecognitionHandler {
    private let requestHandler = VNSequenceRequestHandler()
    
    let optimized: Bool
    let orientation: CGImagePropertyOrientation
    
    init(_ optimized: Bool, orientation: CGImagePropertyOrientation) {
        self.optimized = optimized
        self.orientation = orientation
    }
    
    var lastFaces: [CGRect] = []
    var onFaceBoxes: (([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void)?
    var onPersonMask: ((CVPixelBuffer) -> Void)?
    
    public func setOnPersonMask(_ handler: @escaping ((CVPixelBuffer) -> Void)) {
        self.onPersonMask = handler
    }
    
    public func setOnFaceBoxes(_ handler: @escaping ([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void) {
        self.onFaceBoxes = handler
    }
    
    private let processingQueue = DispatchQueue(label: "face.multi.processing", qos: .userInitiated)
    private let throttle = AdaptiveThrottle(stableFPS: 2.6, movingFPS: 15, startMoving: true)
    
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        processingQueue.async { [weak self] in
            guard let self else { return }
            
            if optimized {
                guard throttle.shouldProcessNow() else { return }
            }
            
            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            detectFaceBoxes(image: buffer)
        }
    }
    
    private func detectFaceBoxes(image: CVPixelBuffer) {
        guard let onFaceBoxes else { return }
        let detectFaces = VNDetectFaceRectanglesRequest { req, err in
            guard let results = req.results as? [VNFaceObservation]
            else { return }
            
            let faces = results
            var boxes: [CGRect] = []
            for face in faces {
                boxes.append(face.boundingBox)
            }
            
            /// Calc if is close by using old + new
            let isCloseBy = self.isCloseBy(old: self.lastFaces, new: boxes)
            
            /// Set the new stable throttle
            self.throttle.setStable(isCloseBy)
            let currentInterval = self.throttle.currentInterval
            
            /// Pass it back to the view
            onFaceBoxes(boxes, image, currentInterval)
            
            /// Set new boxes
            self.lastFaces = boxes
        }
        do {
            try requestHandler.perform(
                [detectFaces],
                on: image,
                orientation: orientation
            )
        } catch {
            print("Vision error:", error)
        }
    }
    
    private func detectPersonMask(image: CVPixelBuffer) {
        guard let onPersonMask else { return }
        let detectPerson = VNGeneratePersonSegmentationRequest { req, err in
            guard let results = req.results as? [VNPixelBufferObservation] else { return }
            
            guard let buffer : CVPixelBuffer = results.first?.pixelBuffer else { return }
            onPersonMask(buffer)
        }
        do {
            try requestHandler.perform(
                [detectPerson],
                on: image,
                orientation: orientation
            )
        } catch {
            print("Vision error:", error)
        }
    }
}
