//
//  CameraPosition.swift
//  SnapCore
//
//  Created by Aryan Rogye on 4/19/26.
//

public enum CameraPosition: Int, CaseIterable {
    case back = 1
    case front = 2
    
    public var title: String {
        switch self {
        case .back:     return "Back Camera"
        case .front:    return "Front Camera"
        }
    }
    
    public var icon: String {
        switch self {
        case .front: return "camera.rotate"
        case .back: return "camera.fill"
        }
    }
    
    public mutating func toggle() {
        self = self == .front ? .back : .front
    }
}
