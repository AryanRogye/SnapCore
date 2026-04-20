//
//  CameraCaptureService+setOnPixelBuffer.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

import AVFoundation

extension CameraCaptureService {
    /**
     * Function sets what happens when capture starts
     */
    public func setOnPixelBuffer(_ handler: @escaping (CVPixelBuffer) -> Void) {
        frameHandler.setOnPixelBuffer(handler)
    }
}
