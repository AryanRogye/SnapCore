//
//  Recorder.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/17/26.
//

#if os(macOS)
import AVFoundation
import CoreImage
import AppKit

@Observable
@MainActor
public final class Recorder {
    
    /// Indicator to know if we are recording or not
    public var isRecording = false
    
    public var recordingInfo: RecordingInfo {
        coordinator.recordingInfo
    }
    
    public var elapsed: TimeInterval = 0
    var timer: Timer? = nil
    
    public var coordinator = RecordingCoordinator()
    
    public init() {
        observeRecording()
    }
    
    private func observeRecording() {
        withObservationTracking {
            _ = isRecording
        } onChange: {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if isRecording {
                    elapsed = 0
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        DispatchQueue.main.async {
                            self.elapsed += 1
                        }
                    }
                } else {
                    timer?.invalidate()
                    timer = nil
                }
                
                observeRecording()
            }
        }
    }
    
    public var recordedURL: URL? {
        coordinator.recordingInfo.recordedURL
    }
    
    public var latestPreviewImage: CGImage? {
        coordinator.recordingInfo.latestPreviewImage
    }
    
    public var isStopping = false
    
    public func toggle(
        with config: RecordingConfig = .recording
    ) async throws {
        if isRecording {
            isStopping = true
            try await coordinator.stopRecording()
            isRecording = false
            isStopping = false
        } else {
            await coordinator.startRecording(
                with: config
            )
            isRecording = true
        }
    }
}
#endif
