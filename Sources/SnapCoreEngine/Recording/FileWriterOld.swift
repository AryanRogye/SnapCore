//
//  FileWriterOld.swift
//  TestingSR
//
//  Legacy AVAssetWriter path retained for fallback/testing.
//

import AVFoundation
import ScreenCaptureKit
import Collections
import DequeModule
import SnapCore

actor FileWriterOld {
    
    var writer              : AVAssetWriter? = nil
    var input               : AVAssetWriterInput? = nil
    var width               : CGFloat? = nil
    var height              : CGFloat? = nil
    var outputURL           : URL? = nil
    var lastPTS             : CMTime = .invalid
    var sessionStartTime    : CMTime = .invalid
    
    public func getOutput() -> URL? {
        outputURL
    }
    
    public func start(outputURL: URL) {
        self.outputURL = outputURL
        self.writer = nil
        self.input = nil
        self.lastPTS = .invalid
        self.width = nil
        self.height = nil
        self.queued_samples.removeAll()
    }
    
    public var queued_samples: Deque<CMSampleBuffer> = []
    
    public func write(
        sample: SendableSampleBuffer,
        info: ValidationInfo,
        onFrameWritten: @escaping () -> Void
    ) async throws {
        
        let presentationTime = await info.getPresentationTime()
        let pixelBuffer = await info.getPixelBuffer()
        
        if !SampleValidator.isValidSample(lastPTS: lastPTS, presentationTime: presentationTime) {
            return
        }
        
        if width == nil || height == nil {
            (self.width, self.height) = getWidthAndHeight(pixelBuffer: pixelBuffer)
        }
        guard let width, let height else { return }
        
        try createWriterIfNeeded(
            sample: sample,
            width: width,
            height: height
        )
        guard let input else { return }
        
        if let writer, writer.status == .failed {
            throw FileWriterError.errorWritingToFile("Writer failed: \(writer.error?.localizedDescription ?? "unknown error")")
        }
        
        queued_samples.append(sample.buffer)
        
        while !queued_samples.isEmpty {
            guard input.isReadyForMoreMediaData else {
                break
            }
            
            let nextSample = queued_samples.removeFirst()
            
            guard input.append(nextSample) else {
                if let writer, let error = writer.error {
                    throw FileWriterError.errorWritingToFile("Writer append failed: \(error)")
                }
                throw FileWriterError.errorWritingToFile("Writer append failed at \(CMTimeGetSeconds(presentationTime))s")
            }
            onFrameWritten()
        }
        
        lastPTS = presentationTime
    }
    
    public func stop() async throws {
        guard let input else { return }
        guard let writer else { return }
        
        guard writer.status == .writing else {
            throw FileWriterError.errorWritingToFile("Writer not in writing state")
        }
        
        input.markAsFinished()
        await writer.finishWriting()
        
        if let error = writer.error {
            throw FileWriterError.errorWritingToFile("FileWriter error: \(error)")
        }
        
        if let url = outputURL {
            try await waitForValidFile(at: url)
            queued_samples.removeAll()
        }
    }
    
    private func waitForValidFile(at url: URL, timeout: TimeInterval = 3.0) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let asset = AVURLAsset(url: url)
            let isPlayable = try? await asset.load(.isPlayable)
            if isPlayable == true { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw FileWriterError.errorWritingToFile("File not valid after timeout")
    }
    
    private func getWidthAndHeight(
        pixelBuffer: CVPixelBuffer
    ) -> (width: CGFloat, height: CGFloat) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        return (CGFloat(width), CGFloat(height))
    }
    
    private func createWriterIfNeeded(
        sample: SendableSampleBuffer,
        width: CGFloat,
        height: CGFloat
    ) throws {
        guard let outputURL else {
            fatalError("outputURL was nil")
        }
        
        if writer == nil || input == nil {
            do {
                try? FileManager.default.removeItem(at: outputURL)
                let w = try AVAssetWriter(url: outputURL, fileType: .mp4)
                
                let fps = 60.0
                let pixels = Double(Int(width) * Int(height))
                let bitsPerPixel: Double = 0.10
                
                let targetBitrate = Int((pixels * fps * bitsPerPixel).rounded())
                let bitrate = min(max(targetBitrate, 20_000_000), 80_000_000)
                
                let input = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: [
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: Int(width),
                        AVVideoHeightKey: Int(height),
                        AVVideoCompressionPropertiesKey: [
                            AVVideoAverageBitRateKey: bitrate,
                            AVVideoExpectedSourceFrameRateKey: 60
                        ]
                    ],
                    sourceFormatHint: CMSampleBufferGetFormatDescription(sample.buffer)
                )
                input.expectsMediaDataInRealTime = true
                guard w.canAdd(input) else {
                    throw FileWriterError.errorCreatingWriter
                }
                w.add(input)
                w.startWriting()
                
                let firstTimestamp = CMSampleBufferGetPresentationTimeStamp(sample.buffer)
                w.startSession(atSourceTime: firstTimestamp)
                
                self.writer = w
                self.input = input
            } catch {
                throw FileWriterError.errorCreatingWriter
            }
        }
    }
}
