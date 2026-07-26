import AVFoundation
import Vision
import XCTest
@testable import SnapCore

final class HandPoseRecognitionTests: XCTestCase {
    private let handler = TestRecognitionHandler()

    func testVisionJointNamesMapToHandJoints() {
        let mappings: [(VNHumanHandPoseObservation.JointName, HandJoint)] = [
            (.wrist, .wrist),
            (.thumbCMC, .thumbCMC),
            (.thumbMP, .thumbMP),
            (.thumbIP, .thumbIP),
            (.thumbTip, .thumbTip),
            (.indexMCP, .indexMCP),
            (.indexPIP, .indexPIP),
            (.indexDIP, .indexDIP),
            (.indexTip, .indexTip),
            (.middleMCP, .middleMCP),
            (.middlePIP, .middlePIP),
            (.middleDIP, .middleDIP),
            (.middleTip, .middleTip),
            (.ringMCP, .ringMCP),
            (.ringPIP, .ringPIP),
            (.ringDIP, .ringDIP),
            (.ringTip, .ringTip),
            (.littleMCP, .littleMCP),
            (.littlePIP, .littlePIP),
            (.littleDIP, .littleDIP),
            (.littleTip, .littleTip),
        ]

        for (visionJoint, handJoint) in mappings {
            XCTAssertEqual(HandJoint(from: visionJoint), handJoint)
        }
    }

    func testIdenticalHandPosesAreClose() {
        let pose = HandPose(joints: validJoints(location: .zero))

        XCTAssertTrue(handler.isCloseBy(old: [pose], new: [pose]))
    }

    func testLargeHandMovementIsNotClose() {
        let oldPose = HandPose(joints: validJoints(location: .zero))
        let newPose = HandPose(joints: validJoints(location: CGPoint(x: 0.2, y: 0)))

        XCTAssertFalse(handler.isCloseBy(old: [oldPose], new: [newPose]))
    }

    func testHandStabilityRequiresAValidSharedJoint() {
        let joints = Dictionary(
            uniqueKeysWithValues: HandJoint.allCases.map {
                ($0, HandJointPoint(location: .zero, confidence: 0))
            }
        )
        let pose = HandPose(joints: joints)

        XCTAssertFalse(handler.isCloseBy(old: [pose], new: [pose]))
    }

    private func validJoints(location: CGPoint) -> [HandJoint: HandJointPoint] {
        Dictionary(
            uniqueKeysWithValues: HandJoint.allCases.map {
                ($0, HandJointPoint(location: location, confidence: 1))
            }
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
