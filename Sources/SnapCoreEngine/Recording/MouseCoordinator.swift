//
//  MouseCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

#if os(macOS)
import AppKit

@Observable
@MainActor
final class MouseCoordinator {
    var lMonitor: Any?
    var monitor : Any?
    
    public var isLeftMouseDown = false
    public var isRightMouseDown = false
    
    public func startMonitoring() {
        lMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [
                .leftMouseUp,
                .leftMouseDown,
                .rightMouseUp,
                .rightMouseDown
            ],
            handler: { [weak self] e in
                guard let self else { return e }
                handleEvent(e)
                return e
            }
        )
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [
                .leftMouseUp,
                .leftMouseDown,
                .rightMouseUp,
                .rightMouseDown
            ],
            handler: { [weak self] e in
                guard let self else { return }
                handleEvent(e)
            }
        )
    }
    public func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        if let lMonitor {
            NSEvent.removeMonitor(lMonitor)
        }
        lMonitor = nil
        monitor = nil
    }
    
    private func handleEvent(_ e: NSEvent) {
        if e.type == .leftMouseDown && !isLeftMouseDown {
            isLeftMouseDown = true
        }
        if e.type == .leftMouseUp && isLeftMouseDown {
            isLeftMouseDown = false
        }
        if e.type == .rightMouseDown && !isRightMouseDown {
            isRightMouseDown = true
        }
        if e.type == .rightMouseUp && isRightMouseDown {
            isRightMouseDown = false
        }
    }
}
#endif
