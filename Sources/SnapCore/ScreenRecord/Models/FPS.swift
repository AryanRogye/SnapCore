//
//  FPS.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

public enum FPS: String, CaseIterable {
    case fps30 = "30 fps"
    case fps60 = "60 fps"
    case fps120 = "120 fps"
    
    var value: Int {
        switch self {
        case .fps30: return 30
        case .fps60: return 60
        case .fps120: return 120
        }
    }
}
