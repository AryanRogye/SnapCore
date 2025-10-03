//
//  ScreenRecordService+contentSharingPicker.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

import ScreenCaptureKit

extension ScreenRecordService: SCContentSharingPickerObserver {
    
    nonisolated public func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        print("User cancelled")
    }
    
    nonisolated public func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            SCContentSharingPicker.shared.isActive = false
            try? await self.startCapture(with: filter)
        }
    }
    
    nonisolated public func contentSharingPickerStartDidFailWithError(_ error: Error) {
        print("Picker error: \(error)")
    }
}
