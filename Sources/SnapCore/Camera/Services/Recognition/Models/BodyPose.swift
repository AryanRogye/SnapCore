// BodyPose.swift
// Models
//
// Created by Aryan Rogye on 7/6/26.
//

import Vision

// MARK: - Models
public enum BodyJoint: String, Sendable, CaseIterable, Hashable {
    case nose
    case leftEye, rightEye
    case leftEar, rightEar
    case neck
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case root
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle

    public init?(from jointName: VNHumanBodyPoseObservation.JointName) {
        switch jointName {
        case .nose: self = .nose
        case .leftEye: self = .leftEye
        case .rightEye: self = .rightEye
        case .leftEar: self = .leftEar
        case .rightEar: self = .rightEar
        case .leftShoulder: self = .leftShoulder
        case .rightShoulder: self = .rightShoulder
        case .neck: self = .neck
        case .leftElbow: self = .leftElbow
        case .rightElbow: self = .rightElbow
        case .leftWrist: self = .leftWrist
        case .rightWrist: self = .rightWrist
        case .leftHip: self = .leftHip
        case .rightHip: self = .rightHip
        case .root: self = .root
        case .leftKnee: self = .leftKnee
        case .rightKnee: self = .rightKnee
        case .leftAnkle: self = .leftAnkle
        case .rightAnkle: self = .rightAnkle
        default: return nil
        }
    }
}

public struct BodyJointPoint: Sendable, Hashable {
    /// Normalized image coordinate with a bottom-left origin.
    public let location: CGPoint

    /// Vision’s confidence score from 0...1.
    public let confidence: Float

    public init(location: CGPoint, confidence: Float) {
        self.location = location
        self.confidence = confidence
    }
}

public struct BodyPose: Sendable, Hashable {
    public let joints: [BodyJoint: BodyJointPoint]

    public init(joints: [BodyJoint : BodyJointPoint]) {
        self.joints = joints
    }

    public subscript(_ joint: BodyJoint) -> BodyJointPoint? {
        joints[joint]
    }
}
