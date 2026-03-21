//
//  VideoScale.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

import Foundation

public enum VideoScale: CaseIterable {
    case normal
    case medium
    case high
    case ultra
    case native
    
    public static var allCases: [VideoScale] {
        return [.normal, .medium, .high, .ultra, .native]
    }
    
    public var stringValue: String {
        switch self {
        case .normal:
            return "1080"
        case .medium:
            return "1440p 2K"
        case .high:
            return "2160p 4K"
        case .ultra:
            return "4320p 8K"
        case .native:
            return "Native"
        }
    }
    
    public var value: Int {
        switch self {
        case .normal:
            return 1080
        case .medium:
            return 1440
        case .high:
            return 2160
        case .ultra:
            return 4320
        case .native:
            return 0
        }
    }
}
