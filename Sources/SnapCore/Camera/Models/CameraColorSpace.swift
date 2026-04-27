//
//  CameraColorSpace.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/21/26.
//

import AVFoundation

public enum CameraColorSpace: String, CaseIterable {
    case sRGB = "sRGB"
    case p3   = "P3"
#if os(iOS)
    case hlg  = "HDR" // HDR
#endif
    
    public var avColorSpace: AVCaptureColorSpace {
        switch self {
        case .sRGB: return .sRGB
        case .p3:   return .P3_D65
#if os(iOS)
        case .hlg:  return .HLG_BT2020
#endif
        }
    }
}
