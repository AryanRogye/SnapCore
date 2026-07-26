//
//  HandRecognitionHandler.swift
//  SnapCore
//

import AVFoundation
import Vision

final class HandRecognitionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, RecognitionHandler {
    private let requestHandler = VNSequenceRequestHandler()

    let optimized: Bool
    let orientation: CGImagePropertyOrientation

    init(_ optimized: Bool, orientation: CGImagePropertyOrientation) {
        self.optimized = optimized
        self.orientation = orientation
    }

    private var lastResult: [HandPose] = []
    var onHandResult: (([HandPose], CVPixelBuffer, CFAbsoluteTime) -> Void)?

    func setOnHandResult(_ handler: @escaping ([HandPose], CVPixelBuffer, CFAbsoluteTime) -> Void) {
        onHandResult = handler
    }

    private let processingQueue = DispatchQueue(label: "hand.processing", qos: .userInitiated)
    private let throttle = AdaptiveThrottle(stableFPS: 2.6, movingFPS: 15, startMoving: true)

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        processingQueue.async { [weak self] in
            guard let self else { return }

            if optimized {
                guard throttle.shouldProcessNow() else { return }
            }

            guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            detectHands(image: buffer)
        }
    }

    private func detectHands(image: CVPixelBuffer) {
        let request = VNDetectHumanHandPoseRequest { [weak self] request, _ in
            guard let self,
                  let observations = request.results as? [VNHumanHandPoseObservation]
            else { return }

            var poses: [HandPose] = []
            for observation in observations {
                do {
                    let points = try observation.recognizedPoints(.all)
                    let joints = points.reduce(into: [HandJoint: HandJointPoint]()) { result, entry in
                        guard let joint = HandJoint(from: entry.key) else { return }
                        result[joint] = HandJointPoint(
                            location: entry.value.location,
                            confidence: entry.value.confidence
                        )
                    }
                    poses.append(HandPose(joints: joints))
                } catch {
                    // Skip observations whose landmarks could not be read.
                }
            }

            let isCloseBy = self.isCloseBy(old: self.lastResult, new: poses)
            self.throttle.setStable(isCloseBy)
            self.onHandResult?(poses, image, self.throttle.currentInterval)
            self.lastResult = poses
        }

        do {
            try requestHandler.perform([request], on: image, orientation: orientation)
        } catch {
            print("Vision error:", error)
        }
    }
}
