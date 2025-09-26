//
//  ScreenshotScaleMode.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/26/25.
//

public enum ScreenshotScaleMode {
    case nativePixels              // default
    case logicalPoints             // points * backingScaleFactor
    case percent(Double)           // 0.1 ... 1.0
    case cappedLongestEdge(Int)    // e.g., 3840
}
