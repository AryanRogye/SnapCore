//
//  VideoScale.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

public enum VideoScale: Int, CaseIterable {
    case normal = 1
    case high = 2
    
    var stringValue: String {
        switch self {
        case .normal:
            return "1x"
        case .high:
            return "2x"
        }
    }
}
