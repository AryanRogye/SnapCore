//
//  FileWriter.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/18/26.
//

import AVFoundation
import SnapCore

enum FileWriterError: Error {
    case errorCreatingWriter
    case errorWritingToFile(String)
}

actor FileWriter {
    
    let recorder: ScreenRecordProviding
    var outputURL: URL? = nil
    var lastPTS: CMTime = .invalid
    
    init(recorder: ScreenRecordProviding) {
        self.recorder = recorder
    }
    
    public func getOutput() -> URL? {
        outputURL
    }
    
    public func start(outputURL: URL) async {
        self.outputURL = outputURL
        self.lastPTS = .invalid
        await recorder.prepareRecordingOutput(url: outputURL)
    }
    
    public func write(
        sample: SendableSampleBuffer,
        info: ValidationInfo,
        onFrameWritten: @escaping () -> Void
    ) async throws {
        
        let presentationTime = await info.getPresentationTime()
        
        if !SampleValidator.isValidSample(lastPTS: lastPTS, presentationTime: presentationTime) {
            return
        }
        
        if let error = await recorder.getRecordingOutputErrorMessage() {
            throw FileWriterError.errorWritingToFile(error)
        }
        
        lastPTS = presentationTime
        onFrameWritten()
    }
    
    public func stop() async throws {
        if let error = await recorder.getRecordingOutputErrorMessage() {
            throw FileWriterError.errorWritingToFile(error)
        }
        
        guard let url = outputURL else { return }
        try await waitForValidFile(at: url)
    }
    
    private func waitForValidFile(at url: URL, timeout: TimeInterval = 20.0) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            print("Timeout: \(Date().timeIntervalSince(start))")
            let asset = AVURLAsset(url: url)
            let isPlayable = try? await asset.load(.isPlayable)
            if isPlayable == true { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw FileWriterError.errorWritingToFile("File not valid after timeout")
    }
    
}
