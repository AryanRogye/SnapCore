//
//  BroadcastController.swift
//  SnapCore
//
//  Created by Aryan Rogye on 5/7/26.
//

#if os(iOS)

import ReplayKit

/// This is the picker that shows up when we click
/// "Start Streaming"
/// This requires passing in a bundle identifier
/// of the Broadcast Upload Extension that we will stream into
public final class BroadcastController {
    
    private let picker: RPSystemBroadcastPickerView
    
    public init(preferredExtension: String) {
        let picker = RPSystemBroadcastPickerView()
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = true
        
        self.picker = picker
    }
    
    public func startBroadcast() {
        guard let button = picker.subviews
            .compactMap({ $0 as? UIButton })
            .first
        else {
            return
        }
        
        button.sendActions(for: .touchUpInside)
    }
}

#endif
