//
//  ProcessInfo+isPreview.swift
//  BodyTrackingExample
//
//  Created by Aryan Rogye on 7/25/26.
//

import Foundation

extension ProcessInfo {
    static var isPreview: Bool {
        processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
