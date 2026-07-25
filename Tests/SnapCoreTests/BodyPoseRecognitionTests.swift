import AVFoundation
import Vision
import XCTest
@testable import SnapCore

final class BodyPoseRecognitionTests: XCTestCase {
    private let handler = TestRecognitionHandler()

    func testStabilityIgnoresInvalidJointsThatWouldDiluteMovement() {
        var oldJoints = invalidJoints(location: .zero)
        var newJoints = invalidJoints(location: .zero)

        oldJoints[.leftShoulder] = point(x: 0.1, confidence: 1)
        newJoints[.leftShoulder] = point(x: 0.3, confidence: 1)

        XCTAssertFalse(
            handler.isCloseBy(
                old: [BodyPose(joints: oldJoints)],
                new: [BodyPose(joints: newJoints)]
            )
        )
    }

    func testStabilityIgnoresMovementFromInvalidJoints() {
        var oldJoints = invalidJoints(location: .zero)
        var newJoints = invalidJoints(location: CGPoint(x: 1, y: 1))

        oldJoints[.leftShoulder] = point(x: 0.1, confidence: 1)
        newJoints[.leftShoulder] = point(x: 0.12, confidence: 1)

        XCTAssertTrue(
            handler.isCloseBy(
                old: [BodyPose(joints: oldJoints)],
                new: [BodyPose(joints: newJoints)]
            )
        )
    }

    func testStabilityRequiresAtLeastOneValidSharedJoint() {
        let pose = BodyPose(joints: invalidJoints(location: .zero))

        XCTAssertFalse(handler.isCloseBy(old: [pose], new: [pose]))
    }

    func testVisionJointNamesMapToBodyJoints() {
        let mappings: [
            (VNHumanBodyPoseObservation.JointName, BodyJoint)
        ] = [
            (.nose, .nose),
            (.leftEye, .leftEye),
            (.rightEye, .rightEye),
            (.leftEar, .leftEar),
            (.rightEar, .rightEar),
            (.neck, .neck),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.root, .root),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle),
        ]

        for (visionJoint, bodyJoint) in mappings {
            XCTAssertEqual(BodyJoint(from: visionJoint), bodyJoint)
        }
    }

    private func invalidJoints(location: CGPoint) -> [BodyJoint: BodyJointPoint] {
        Dictionary(
            uniqueKeysWithValues: BodyJoint.allCases.map {
                ($0, BodyJointPoint(location: location, confidence: 0))
            }
        )
    }

    private func point(x: CGFloat, confidence: Float) -> BodyJointPoint {
        BodyJointPoint(
            location: CGPoint(x: x, y: 0.5),
            confidence: confidence
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
