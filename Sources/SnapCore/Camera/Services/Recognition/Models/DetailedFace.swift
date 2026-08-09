//
//  DetailedFace.swift
//  SnapCore
//

import Vision

/// A facial region returned by Vision's face-landmark request.
public enum DetailedFaceRegion: String, Sendable, CaseIterable, Hashable {
    case faceContour
    case leftEye
    case rightEye
    case leftEyebrow
    case rightEyebrow
    case nose
    case noseCrest
    case medianLine
    case outerLips
    case innerLips
    case leftPupil
    case rightPupil
}

/// A face bounding box and its normalized landmark regions.
///
/// Region points use Vision's normalized face coordinates. They are normalized
/// relative to the face bounding box, with a lower-left origin.
public struct DetailedFace: Sendable, Hashable {
    public let boundingBox: CGRect
    public let landmarks: [DetailedFaceRegion: [CGPoint]]
    public let confidence: Float
    public let roll: Double?
    public let yaw: Double?
    public let pitch: Double?

    public init(
        boundingBox: CGRect,
        landmarks: [DetailedFaceRegion: [CGPoint]],
        confidence: Float,
        roll: Double? = nil,
        yaw: Double? = nil,
        pitch: Double? = nil
    ) {
        self.boundingBox = boundingBox
        self.landmarks = landmarks
        self.confidence = confidence
        self.roll = roll
        self.yaw = yaw
        self.pitch = pitch
    }

    public subscript(_ region: DetailedFaceRegion) -> [CGPoint]? {
        landmarks[region]
    }
}
