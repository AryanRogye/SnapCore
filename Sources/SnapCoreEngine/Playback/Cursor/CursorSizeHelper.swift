//
//  CursorSizeHelper.swift
//  PointerKit
//
//  Created by Aryan Rogye on 3/23/26.
//

import Foundation

#if os(macOS)
typealias CGSConnectionID = UInt32
typealias CGSWindowCount  = UInt32
typealias CGSSpaceID      = UInt64
typealias CGSSpaceMask    = UInt64

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetCursorScale")
func CGSGetCursorScale(_ cid: CGSConnectionID, _ scale: UnsafeMutablePointer<Float>)

public final class CursorSizeHelper {
    public static func cursorScale() -> Float {
        var value: Float = 0
        CGSGetCursorScale(CGSMainConnectionID(), &value)
        return value
    }
}
#endif
