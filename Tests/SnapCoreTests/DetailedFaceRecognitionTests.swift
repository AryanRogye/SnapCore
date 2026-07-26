import AVFoundation
import XCTest
@testable import SnapCore

final class DetailedFaceRecognitionTests: XCTestCase {
    private let handler = TestRecognitionHandler()

    func testDetailedFaceStoresLandmarkRegions() {
        let points = [CGPoint(x: 0.25, y: 0.75), CGPoint(x: 0.5, y: 0.5)]
        let face = DetailedFace(
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.5),
            landmarks: [.leftEye: points],
            confidence: 0.9
        )

        XCTAssertEqual(face[.leftEye], points)
        XCTAssertEqual(face.confidence, 0.9)
    }

    func testIdenticalDetailedFacesAreClose() {
        let face = makeFace(offset: .zero)

        XCTAssertTrue(handler.isCloseBy(old: [face], new: [face]))
    }

    func testLargeDetailedFaceMovementIsNotClose() {
        let oldFace = makeFace(offset: .zero)
        let newFace = makeFace(offset: CGPoint(x: 0.2, y: 0))

        XCTAssertFalse(handler.isCloseBy(old: [oldFace], new: [newFace]))
    }

    func testDetailedFaceStabilityRequiresSharedLandmarks() {
        let oldFace = makeFace(offset: .zero)
        let newFace = DetailedFace(
            boundingBox: oldFace.boundingBox,
            landmarks: [.leftEye: [CGPoint(x: 0.1, y: 0.1)]],
            confidence: 1
        )

        XCTAssertFalse(handler.isCloseBy(old: [oldFace], new: [newFace]))
    }

    private func makeFace(offset: CGPoint) -> DetailedFace {
        DetailedFace(
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            landmarks: [
                .leftEye: [
                    CGPoint(x: 0.2 + offset.x, y: 0.3 + offset.y),
                    CGPoint(x: 0.3 + offset.x, y: 0.3 + offset.y),
                ],
                .nose: [CGPoint(x: 0.5 + offset.x, y: 0.5 + offset.y)],
            ],
            confidence: 1
        )
    }
}

private final class TestRecognitionHandler: RecognitionHandler {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {}
}
