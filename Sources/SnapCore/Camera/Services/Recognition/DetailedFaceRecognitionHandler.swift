//
//  DetailedFaceRecognitionHandler.swift
//  SnapCore
//

import AVFoundation
import Vision

final class DetailedFaceRecognitionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, RecognitionHandler {
    private let requestHandler = VNSequenceRequestHandler()

    let optimized: Bool
    let orientation: CGImagePropertyOrientation

    init(_ optimized: Bool, orientation: CGImagePropertyOrientation) {
        self.optimized = optimized
        self.orientation = orientation
    }

    private var lastResult: [DetailedFace] = []
    var onDetailedFaceResult: (([DetailedFace], CVPixelBuffer, CFAbsoluteTime) -> Void)?

    func setOnDetailedFaceResult(
        _ handler: @escaping ([DetailedFace], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) {
        onDetailedFaceResult = handler
    }

    private let processingQueue = DispatchQueue(label: "face.detailed.processing", qos: .userInitiated)
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
            detectDetailedFaces(image: buffer)
        }
    }

    private func detectDetailedFaces(image: CVPixelBuffer) {
        let request = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let self,
                  let observations = request.results as? [VNFaceObservation]
            else { return }

            let faces = observations.compactMap(makeDetailedFace)
            let isCloseBy = self.isCloseBy(old: self.lastResult, new: faces)
            self.throttle.setStable(isCloseBy)
            self.onDetailedFaceResult?(faces, image, self.throttle.currentInterval)
            self.lastResult = faces
        }

        do {
            try requestHandler.perform([request], on: image, orientation: orientation)
        } catch {
            print("Vision error:", error)
        }
    }

    private func makeDetailedFace(_ observation: VNFaceObservation) -> DetailedFace? {
        guard let landmarks = observation.landmarks else { return nil }

        let regions: [(DetailedFaceRegion, VNFaceLandmarkRegion2D?)] = [
            (.faceContour, landmarks.faceContour),
            (.leftEye, landmarks.leftEye),
            (.rightEye, landmarks.rightEye),
            (.leftEyebrow, landmarks.leftEyebrow),
            (.rightEyebrow, landmarks.rightEyebrow),
            (.nose, landmarks.nose),
            (.noseCrest, landmarks.noseCrest),
            (.medianLine, landmarks.medianLine),
            (.outerLips, landmarks.outerLips),
            (.innerLips, landmarks.innerLips),
            (.leftPupil, landmarks.leftPupil),
            (.rightPupil, landmarks.rightPupil),
        ]

        let pointsByRegion = regions.reduce(into: [DetailedFaceRegion: [CGPoint]]()) { result, entry in
            guard let region = entry.1,
                  region.pointCount > 0
            else { return }

            result[entry.0] = region.normalizedPoints
        }

        return DetailedFace(
            boundingBox: observation.boundingBox,
            landmarks: pointsByRegion,
            confidence: landmarks.confidence
        )
    }
}
