//
//  CameraFPS.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/20/26.
//

public enum CameraFPS: Double, CaseIterable {
    case sixty = 60
    case onetwenty = 120
    
    public var title: String {
        switch self {
        case .sixty: return "60 FPS"
        case .onetwenty: return "120 FPS"
        }
    }
}
