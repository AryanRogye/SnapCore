//
//  VideoRotationTarget.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/25/26.
//

import AVFoundation

final class VideoRotationTarget: @unchecked Sendable {
    private weak var connection: AVCaptureConnection?

    init(connection: AVCaptureConnection) {
        self.connection = connection
    }

    func apply(_ angle: CGFloat) {
        guard let connection else { return }
        guard connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}
