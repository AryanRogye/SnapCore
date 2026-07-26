//
//  MultiRecognitionConfiguration.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/26/26.
//

public enum MultiRecognitionConfiguration: Sendable {
    case none
    case body
    case hand
    case face
    case detailedFace
    case body3D(trackingMovement: Bool)
}
