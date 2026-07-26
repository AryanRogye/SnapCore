// Body3DPose.swift
// Models

import simd
import Vision

/// A body joint reported by Vision's 3D human-pose request.
public enum Body3DJoint: String, Sendable, CaseIterable, Hashable {
    case root
    case spine
    case centerShoulder
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
    case centerHead
    case topHead

    /// Converts a Vision 3D joint name into SnapCore's joint model.
    public init?(from jointName: VNHumanBodyPose3DObservation.JointName) {
        switch jointName {
        case .root: self = .root
        case .spine: self = .spine
        case .centerShoulder: self = .centerShoulder
        case .leftShoulder: self = .leftShoulder
        case .rightShoulder: self = .rightShoulder
        case .leftElbow: self = .leftElbow
        case .rightElbow: self = .rightElbow
        case .leftWrist: self = .leftWrist
        case .rightWrist: self = .rightWrist
        case .leftHip: self = .leftHip
        case .rightHip: self = .rightHip
        case .leftKnee: self = .leftKnee
        case .rightKnee: self = .rightKnee
        case .leftAnkle: self = .leftAnkle
        case .rightAnkle: self = .rightAnkle
        case .centerHead: self = .centerHead
        case .topHead: self = .topHead
        default: return nil
        }
    }
}

/// The world-space transform and optional image projection of a 3D body joint.
public struct Body3DJointPoint: Sendable {
    /// Vision's world-space transform for the joint.
    public let position: simd_float4x4

    /// The joint projected into the source image, normalized with a lower-left origin.
    public let imagePoint: CGPoint?

    /// Creates a joint point from its transform and optional image projection.
    public init(position: simd_float4x4, imagePoint: CGPoint? = nil) {
        self.position = position
        self.imagePoint = imagePoint
    }

    /// The translation component of ``position``.
    public var translation: SIMD3<Float> {
        SIMD3(position.columns.3.x, position.columns.3.y, position.columns.3.z)
    }
}

extension Body3DJointPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        translation.hash(into: &hasher)
        hasher.combine(imagePoint?.x)
        hasher.combine(imagePoint?.y)
    }

    public static func == (lhs: Body3DJointPoint, rhs: Body3DJointPoint) -> Bool {
        lhs.translation == rhs.translation &&
        lhs.imagePoint == rhs.imagePoint
    }
}

/// A detected 3D body pose keyed by joint.
public struct BodyPose3D: Sendable, Hashable {
    /// The detected joints in this pose.
    public let joints: [Body3DJoint: Body3DJointPoint]

    /// Creates a pose from its detected joints.
    public init(joints: [Body3DJoint: Body3DJointPoint]) {
        self.joints = joints
    }

    /// Returns the point for a joint when Vision detected it.
    public subscript(_ joint: Body3DJoint) -> Body3DJointPoint? {
        joints[joint]
    }
}
