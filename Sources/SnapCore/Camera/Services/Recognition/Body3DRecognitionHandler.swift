//
//  Body3DRecognitionHandler.swift
//  SnapCore
//

import AVFoundation
import Vision

final class Body3DRecognitionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, RecognitionHandler {
    let optimized: Bool
    let orientation: CGImagePropertyOrientation

    init(_ optimized: Bool, orientation: CGImagePropertyOrientation) {
        self.optimized = optimized
        self.orientation = orientation
    }

    private var lastResult: [BodyPose3D] = []
    var onBody3DResult: (([BodyPose3D], CVPixelBuffer, CFAbsoluteTime) -> Void)?

    public func setOnBody3DResult(_ handler: @escaping ([BodyPose3D], CVPixelBuffer, CFAbsoluteTime) -> Void) {
        self.onBody3DResult = handler
    }

    private let processingQueue = DispatchQueue(label: "body3d.processing", qos: .userInitiated)
    private let processingGate = DispatchSemaphore(value: 2)
    private let throttle = AdaptiveThrottle(stableFPS: 2.6, movingFPS: 15, startMoving: true)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard width > 0 && height > 0 else {
            print(
                "⚠️ Drop frame: Received an empty pixel buffer " +
                "(\(width)x\(height)). Skipping Vision pipeline."
            )
            return
        }

        guard processingGate.wait(timeout: .now()) == .success else { return }

        let processingGate = processingGate
        processingQueue.async { [weak self] in
            guard let self else {
                // release the lock
                processingGate.signal()
                return
            }

            if optimized {
                guard throttle.shouldProcessNow() else {
                    // release the lock
                    processingGate.signal()
                    return
                }
            }

            Task { [weak self] in
                // release the lock at the end
                defer { processingGate.signal() }
                guard let self else { return }

                await detectBody3D(image: pixelBuffer)
            }
        }
    }

    private func detectBody3D(image: CVPixelBuffer) async {
        if #available(iOS 18.0, macOS 15.0, *) {
            await detectBody3DUsingModernVision(image: image)
        } else {
            detectBody3DUsingLegacyVision(image: image)
        }
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func detectBody3DUsingModernVision(image: CVPixelBuffer) async {
        let request = DetectHumanBodyPose3DRequest()

        do {
            let observations = try await request.perform(on: image)

            let poses = observations.map { observation in
                var jointMap: [Body3DJoint: Body3DJointPoint] = [:]

                for (jointName, joint) in observation.allJoints() {
                    guard let body3DJoint = Body3DJoint(
                        rawValue: jointName.rawValue
                    ) else {
                        continue
                    }

                    jointMap[body3DJoint] = Body3DJointPoint(
                        position: joint.position,
                        imagePoint: observation.pointInImage(
                            for: jointName
                        ).cgPoint
                    )
                }

                return BodyPose3D(joints: jointMap)
            }

            publish(poses: poses, image: image)
        } catch {
            publish(poses: [], image: image)
        }
    }

    private func detectBody3DUsingLegacyVision(image: CVPixelBuffer) {
        let bodyPoseRequest = VNDetectHumanBodyPose3DRequest()
        let requestHandler = VNImageRequestHandler(
            cvPixelBuffer: image,
            options: [:]
        )

        do {
            try requestHandler.perform([bodyPoseRequest])
        } catch {
            publish(poses: [], image: image)
            return
        }

        var poses: [BodyPose3D] = []

        for observation in bodyPoseRequest.results ?? [] {
            do {
                var jointMap: [Body3DJoint: Body3DJointPoint] = [:]

                let recognizedPoints = try observation.recognizedPoints(.all)
                for (key, value) in recognizedPoints {
                    guard let body3DJoint = Body3DJoint(from: key) else { continue }
                    jointMap[body3DJoint] = Body3DJointPoint(
                        position: value.position,
                        imagePoint: try? observation.pointInImage(key).location
                    )
                }

                poses.append(BodyPose3D(joints: jointMap))
            } catch {
                // Joints were not detected for this observation.
            }
        }

        publish(poses: poses, image: image)
    }

    private func publish(poses: [BodyPose3D], image: CVPixelBuffer) {
        let isCloseBy = isCloseBy(old: lastResult, new: poses)
        throttle.setStable(isCloseBy)

        onBody3DResult?(poses, image, throttle.currentInterval)
        lastResult = poses
    }
}
