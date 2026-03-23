//
//  MouseModels.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/23/26.
//

import SwiftUI

public struct CurrentMouseInfo: Equatable {
    public var point: CGPoint?
    public var isLeftClick: Bool
    public var isRightClick: Bool
}

public struct CursorMotionState {
    public var previousPoint: CGPoint?
    public var currentAngle: CGFloat = -20
    public var dx: CGFloat = 0
    public var dy: CGFloat = 0
    
    public static let baseAngle : CGFloat = -20
    
    public init() {
        
    }
}
