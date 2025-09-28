//
//  ScreenshotService+screenUnderMouse.swift
//  SnapCore
//
//  Created by Aryan Rogye on 9/28/25.
//

import AppKit

extension ScreenshotService {
    public static func screenUnderMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) }
    }
}
