//
//  HandPose.swift
//  SnapCore
//

import Vision

/// A landmark in a detected hand.
public enum HandJoint: String, Sendable, CaseIterable, Hashable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip

    public init?(from jointName: VNHumanHandPoseObservation.JointName) {
        switch jointName {
        case .wrist: self = .wrist
        case .thumbCMC: self = .thumbCMC
        case .thumbMP: self = .thumbMP
        case .thumbIP: self = .thumbIP
        case .thumbTip: self = .thumbTip
        case .indexMCP: self = .indexMCP
        case .indexPIP: self = .indexPIP
        case .indexDIP: self = .indexDIP
        case .indexTip: self = .indexTip
        case .middleMCP: self = .middleMCP
        case .middlePIP: self = .middlePIP
        case .middleDIP: self = .middleDIP
        case .middleTip: self = .middleTip
        case .ringMCP: self = .ringMCP
        case .ringPIP: self = .ringPIP
        case .ringDIP: self = .ringDIP
        case .ringTip: self = .ringTip
        case .littleMCP: self = .littleMCP
        case .littlePIP: self = .littlePIP
        case .littleDIP: self = .littleDIP
        case .littleTip: self = .littleTip
        default: return nil
        }
    }
}

/// A normalized hand landmark and its Vision confidence score.
public struct HandJointPoint: Sendable, Hashable {
    public let location: CGPoint
    public let confidence: Float

    public init(location: CGPoint, confidence: Float) {
        self.location = location
        self.confidence = confidence
    }
}

/// The recognized landmarks for one hand.
public struct HandPose: Sendable, Hashable {
    public let joints: [HandJoint: HandJointPoint]

    public init(joints: [HandJoint: HandJointPoint]) {
        self.joints = joints
    }

    public subscript(_ joint: HandJoint) -> HandJointPoint? {
        joints[joint]
    }
}
