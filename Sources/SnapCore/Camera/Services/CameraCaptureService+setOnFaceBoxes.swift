//
//  CameraCaptureService+setOnFaceBoxes.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/22/26.
//

import AVFoundation

extension CameraCaptureService {
    public func setOnFaceBoxes(
        _ handler: @escaping ([CGRect], CVPixelBuffer, CFAbsoluteTime) -> Void
    ) {
        self.onFaceBoxes = handler
    }
    
    public func setOnPersonMask(
        _ handler: @escaping ((CVPixelBuffer) -> Void)
    ) {
        self.onPersonMask = handler
    }
}
