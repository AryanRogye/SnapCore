//
//  BodyRecognitionHandler.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/24/26.
//

import AVFoundation
import Vision

// MARK: - Handler
final class BodyRecognitionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, RecognitionHandler {
    private let requestHandler = VNSequenceRequestHandler()

    let optimized: Bool
    let orientation: CGImagePropertyOrientation

    init(_ optimized: Bool, orientation: CGImagePropertyOrientation) {
        self.optimized = optimized
        self.orientation = orientation
    }

    private var lastResult: [BodyPose] = []
    var onBodyResult: (([BodyPose], CVPixelBuffer, CFAbsoluteTime) -> Void)?

    public func setOnBodyResult(_ handler: @escaping ([BodyPose], CVPixelBuffer, CFAbsoluteTime) -> Void) {
        self.onBodyResult = handler
    }

    private let processingQueue = DispatchQueue(label: "body.processing", qos: .userInitiated)
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

            detectBody(image: buffer)
        }
    }

    private func detectBody(image: CVPixelBuffer) {
        let detectBodyPose = VNDetectHumanBodyPoseRequest { req, err in
            guard let observations = req.results as? [VNHumanBodyPoseObservation]
            else { return }

            var poses: [BodyPose] = []

            for observation in observations {
                do {
                    var jointMap: [BodyJoint: BodyJointPoint] = [:]

                    func merge(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
                        for (key, value) in points {
                            guard let bodyJoint = BodyJoint(from: key) else { continue }
                            jointMap[bodyJoint] = BodyJointPoint(location: value.location, confidence: value.confidence)
                        }
                    }

                    merge(try observation.recognizedPoints(.face))
                    merge(try observation.recognizedPoints(.torso))
                    merge(try observation.recognizedPoints(.leftArm))
                    merge(try observation.recognizedPoints(.rightArm))
                    merge(try observation.recognizedPoints(.leftLeg))
                    merge(try observation.recognizedPoints(.rightLeg))

                    poses.append(BodyPose(joints: jointMap))
                } catch {
                    // face/group not detected, skip this observation
                }
            }

            /// Calc if is close by using old and new poses
            let isCloseBy = self.isCloseBy(old: self.lastResult, new: poses)

            /// Set new stable throttle based on the new calculation
            self.throttle.setStable(isCloseBy)
            let currentInterval = self.throttle.currentInterval

            /// Pass it back to the view
            self.onBodyResult?(poses, image, currentInterval)

            /// Set new poses
            self.lastResult = poses
        }
        do {
            try requestHandler.perform(
                [detectBodyPose],
                on: image,
                orientation: orientation
            )
        } catch {
            print("Vision error:", error)
        }
    }
}
