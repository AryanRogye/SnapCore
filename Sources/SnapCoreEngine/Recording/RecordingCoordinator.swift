//
//  RecordingCoordinator.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

import AppKit
import CoreMedia
import ScreenCaptureKit
import SnapCore
import SnapCore

@Observable
@MainActor
public final class RecordingCoordinator {
    
    /// Recorder service from ``SnapCore``
    var recorder : ScreenRecordProviding
    
    public var scale: VideoScale = .native
    
    public var lastBackingScaleFactorUsed: CGFloat = 2.0

    /// Our "File Writer"
    let fileWriter: FileWriter
    
    let recordingInfo = RecordingInfo()
    
    var mouseCoordinator = MouseCoordinator()
    
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    

    public init() {
        let recorder = ScreenRecordService()
        self.recorder = recorder
        self.fileWriter = FileWriter(recorder: recorder)
    }
    
    var recordingActivity: NSObjectProtocol?
    
    private var frameCount = 0
    private let processEvery = 20
    
    public func startRecording() async {
        let temp = getTemp()
        await fileWriter.start(outputURL: temp)
        
        self.recordingInfo.clear()
        self.recordingInfo.setURL(temp)
        
        beginRecordingActivity()
        mouseCoordinator.startMonitoring()
        
        recorder.onScreenFrame = { sample in
            do {
                guard let info = SampleValidator.isValidSample(sample) else { return }
                
                try await self.fileWriter.write(
                    sample: sample,
                    info: info,
                    onFrameWritten: { [weak self] in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            let mouse = NSEvent.mouseLocation
                            self.recordingInfo.append(
                                FrameInfo(
                                    time: sample.buffer.presentationTimeStamp,
                                    mouse: mouse,
                                    leftMouseDown: self.mouseCoordinator.isLeftMouseDown,
                                    rightMouseDown: self.mouseCoordinator.isRightMouseDown
                                )
                            )
                            self.frameCount += 1
                            guard self.frameCount % self.processEvery == 0 else { return }
                            if let img = self.convert(sample: sample.buffer) {
                                self.recordingInfo.setLastImage(img)
                            }
                        }
                    }
                )
                

            } catch let e as FileWriterError {
                switch e {
                case .errorCreatingWriter:
                    print("Error Creating Writer")
                case .errorWritingToFile(let error):
                    print(error)
                }
            } catch {
                print("Error: \(error)")
            }
        }
        recorder.startRecording(
            scale: scale,
            showsCursor: true,
            capturesAudio: false,
            fps: .fps120
        )
        self.lastBackingScaleFactorUsed = self.recorder.getLastScaleFactorUsed()
    }
    
    public func stopRecording() async throws {
        defer {
            endRecordingActivity()
        }
        
        await recorder.stopRecording()
        mouseCoordinator.stopMonitoring()
        
        try await stopFileWriter()
        analyzeCachedFilter()
        
    }
    
    private func analyzeCachedFilter() {
        if let filter = recorder.getCachedFilter() {
            let displays = filter.includedDisplays
            guard !displays.isEmpty else { print("Couldnt Analyze Filter - No Displays"); return }
            
            if let first = displays.first {
                recordingInfo.displayWidth = first.width
                recordingInfo.displayHeight = first.height
                recordingInfo.frame = first.frame
            }
        }
    }
    
    private func stopFileWriter() async throws {
        do {
            try await fileWriter.stop()
        } catch let e as FileWriterError {
            switch e {
            case .errorCreatingWriter:
                print("Error Creating Writer")
            case .errorWritingToFile(let error):
                print(error)
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    /**
     * Function makes a temp URL and saves the video to this before processing
     */
    private func getTemp() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }
    
    private func beginRecordingActivity() {
        endRecordingActivity()
        recordingActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Screen recording in progress"
        )
    }
    
    private func endRecordingActivity() {
        guard let recordingActivity else { return }
        ProcessInfo.processInfo.endActivity(recordingActivity)
        self.recordingActivity = nil
    }
    
    private func convert(sample: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return nil }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        guard let cg = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return cg
    }
}
