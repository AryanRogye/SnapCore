import AVFoundation
import simd
import Vision
import XCTest
@testable import SnapCore

final class Body3DPoseRecognitionTests: XCTestCase {
    private let handler = TestRecognitionHandler()

    func testVision3DJointNamesMapToBody3DJoints() {
        let mappings: [
            (VNHumanBodyPose3DObservation.JointName, Body3DJoint)
        ] = [
            (.root, .root),
            (.spine, .spine),
            (.centerShoulder, .centerShoulder),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle),
            (.centerHead, .centerHead),
            (.topHead, .topHead),
        ]

        for (visionJoint, body3DJoint) in mappings {
            XCTAssertEqual(Body3DJoint(from: visionJoint), body3DJoint)
        }
    }

    func testBody3DJointPointTranslation() {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(0.5, 1.0, -0.3, 1.0)
        let point = Body3DJointPoint(position: matrix)
        XCTAssertEqual(point.translation.x, 0.5)
        XCTAssertEqual(point.translation.y, 1.0)
        XCTAssertEqual(point.translation.z, -0.3)
    }

    func testStabilityDetectsIdenticalPosesAsClose() {
        let pose = makePose(translation: SIMD3<Float>(0.1, 0.2, 0.3))
        XCTAssertTrue(
            handler.isCloseBy(
                old: [pose],
                new: [pose],
                threshold: 0.01
            )
        )
    }

    func testStabilityDetectsSmallMovementAsClose() {
        let oldPose = makePose(translation: SIMD3<Float>(0, 0, 0))
        let newPose = makePose(translation: SIMD3<Float>(0.03, 0, 0))
        XCTAssertTrue(
            handler.isCloseBy(
                old: [oldPose],
                new: [newPose],
                threshold: 0.05
            )
        )
    }

    func testStabilityDetectsLargeMovementAsNotClose() {
        let oldPose = makePose(translation: SIMD3<Float>(0, 0, 0))
        let newPose = makePose(translation: SIMD3<Float>(0.3, 0, 0))
        XCTAssertFalse(
            handler.isCloseBy(
                old: [oldPose],
                new: [newPose],
                threshold: 0.05
            )
        )
    }

    func testStabilityDifferentCountsReturnsFalse() {
        let pose = makePose(translation: .zero)
        XCTAssertFalse(
            handler.isCloseBy(
                old: [pose],
                new: [pose, pose],
                threshold: 0.05
            )
        )
    }

    func testStabilityEmptyArraysReturnsTrue() {
        XCTAssertTrue(
            handler.isCloseBy(
                old: [BodyPose3D](),
                new: [BodyPose3D](),
                threshold: 0.05
            )
        )
    }

    // MARK: - Helpers

    private func makePose(translation: SIMD3<Float>) -> BodyPose3D {
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1.0)
        let point = Body3DJointPoint(position: matrix)
        var joints: [Body3DJoint: Body3DJointPoint] = [:]
        for joint in Body3DJoint.allCases {
            joints[joint] = point
        }
        return BodyPose3D(joints: joints)
    }
}

private final class TestRecognitionHandler: RecognitionHandler {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {}
}
