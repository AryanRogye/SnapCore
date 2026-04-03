//
//  Exporter.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import AVFoundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

public enum ExportError: Error {
    case noVideoTrack
    case noAudioTrack
    case cannotAddReaderOutput
    case cannotAddWriterInput
    case readerFailedToStart
    case writerFailedToStart(String)
    case cgImageCreationFailed
    case missingPixelBufferPool
    case pixelBufferCreationFailed
    case missingBaseAddress
    case contextCreationFailed
    case appendFailed
}

public final class Exporter {
    
    private let imageSharpener = ImageSharpener()
    private let imageContrastBooster = ImageContrastBooster()
    
    public init() {}
    
#if os(macOS)
    @discardableResult
    public func export(
        recordingInfo: RecordingInfo,
        start: Float64,
        end: Float64,
        sharpness: Float,
        contrast: Float
    ) async throws -> URL? {
        guard let url = await recordingInfo.url else {
            fatalError("Original recording URL is missing.")
        }
        
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.noVideoTrack
        }
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw ExportError.noAudioTrack
        }
        
        let duration = try await asset.load(.duration)
        
        let startTime = CMTimeMultiplyByFloat64(duration, multiplier: start)
        let endTime = CMTimeMultiplyByFloat64(duration, multiplier: end)
        let durationOfSegment = CMTimeSubtract(endTime, startTime)
        
        let selectedRange = CMTimeRange(start: startTime, duration: durationOfSegment)
        
        let composition = AVMutableComposition()
        try await composition.insertTimeRange(selectedRange, of: asset, at: .zero)
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        
        /// setup the reader
        let (reader, videoOutput, audioOutput) = try setupReader(
            asset: asset,
            selectedRange: selectedRange,
            videoTrack: videoTrack,
            audioTracks: audioTracks
        )
        
        try await setupWriter(
            reader: reader,
            videoOutput: videoOutput,
            audioOutput: audioOutput,
            outputURL: outputURL,
            videoTrack: videoTrack,
            audioTracks: audioTracks,
            startTime: startTime,
            sharpness: sharpness,
            contrast: contrast
        )
        NSWorkspace.shared.open(outputURL)
        return outputURL
    }
#endif

#if os(macOS) || os(iOS)
    public func export(
        composition: AVMutableComposition,
        sharpness: Float,
        contrast: Float
    ) async throws -> URL? {
        guard let videoTrack = try await composition.loadTracks(withMediaType: .video).first else {
            throw ExportError.noVideoTrack
        }
        let audioTracks = try await composition.loadTracks(withMediaType: .audio)
        
        let duration = try await composition.load(.duration)
        let startTime: CMTime = .zero
        let selectedRange = CMTimeRange(start: .zero, duration: duration)
        
        #if os(macOS)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        #elseif os(iOS)
        let outputURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        #endif

        let (reader, videoOutput, audioOutput) = try setupReader(
            asset: composition,
            selectedRange: selectedRange,
            videoTrack: videoTrack,
            audioTracks: audioTracks
        )
        print("Done Setting Up Reader")

        try await setupWriter(
            reader: reader,
            videoOutput: videoOutput,
            audioOutput: audioOutput,
            outputURL: outputURL,
            videoTrack: videoTrack,
            audioTracks: audioTracks,
            startTime: startTime,
            sharpness: sharpness,
            contrast: contrast
        )
        
        return outputURL
    }
#endif
    
    private func setupReader(
        asset: AVAsset,
        selectedRange: CMTimeRange,
        videoTrack: AVAssetTrack,
        audioTracks: [AVAssetTrack]
    ) throws -> (AVAssetReader, AVAssetReaderTrackOutput, AVAssetReaderOutput?) {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = selectedRange
        
        // MARK: Video output
        let videoOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: videoOutputSettings
        )
        videoOutput.alwaysCopiesSampleData = false
        
        guard reader.canAdd(videoOutput) else {
            throw ExportError.cannotAddReaderOutput
        }
        reader.add(videoOutput)
        
        // MARK: Audio output
        var audioOutput: AVAssetReaderOutput? = nil
        if !audioTracks.isEmpty {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16
            ]
            let ao = AVAssetReaderAudioMixOutput(
                audioTracks: audioTracks,
                audioSettings: audioOutputSettings
            )
            ao.alwaysCopiesSampleData = false
            
            guard reader.canAdd(ao) else {
                throw ExportError.cannotAddReaderOutput
            }
            reader.add(ao)
            audioOutput = ao
        }
        
        return (reader, videoOutput, audioOutput)
    }

    private func setupWriter(
        reader: AVAssetReader,
        videoOutput: AVAssetReaderOutput,
        audioOutput: AVAssetReaderOutput?,
        outputURL: URL,
        videoTrack: AVAssetTrack,
        audioTracks: [AVAssetTrack],
        startTime: CMTime,
        sharpness: Float,
        contrast: Float,
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        
        let naturalSize = try await videoTrack.load(.naturalSize)

        let preferredTransform = try await videoTrack.load(.preferredTransform)

        let outputSize = adjustedVideoSize(for: naturalSize, transform: preferredTransform)
        
        let originalBitrate = try await videoTrack.load(.estimatedDataRate)
        let targetBitrate = originalBitrate > 0 ? Int(originalBitrate) : 15_000_000

        print("naturalSize:", naturalSize)
        print("preferredTransform:", preferredTransform)
        print("outputSize:", outputSize)
        print("targetBitrate:", targetBitrate)
        
        let writerInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
//            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outputSize.width,
            AVVideoHeightKey: outputSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetBitrate,
//                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                AVVideoProfileLevelKey: "HEVC_Main_AutoLevel"
            ]
        ]
        
        /// for video
        let writerInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: writerInputSettings
        )
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = preferredTransform
        
        let adaptorAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputSize.width,
            kCVPixelBufferHeightKey as String: outputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: adaptorAttributes
        )
        
        guard writer.canAdd(writerInput) else {
            throw ExportError.cannotAddWriterInput
        }
        writer.add(writerInput)
        
        /// for audio
        var audioWriterInput: AVAssetWriterInput?
        if let primaryAudioTrack = audioTracks.first {
            let formatDescriptions = try await primaryAudioTrack.load(.formatDescriptions)
            let audioFormatDesc = formatDescriptions.first
            let streamDescription = audioFormatDesc.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            let sampleRate = streamDescription?.mSampleRate ?? 44_100
            let channelCount = Int(streamDescription?.mChannelsPerFrame ?? 2)
            let audioInputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: max(channelCount, 1),
                AVSampleRateKey: sampleRate,
                AVEncoderBitRateKey: 192_000
            ]
            
            let awi = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioInputSettings
            )
            awi.expectsMediaDataInRealTime = false
            
            guard writer.canAdd(awi) else {
                throw ExportError.cannotAddWriterInput
            }
            writer.add(awi)
            audioWriterInput = awi
        }

        guard reader.startReading() else {
            throw reader.error ?? ExportError.readerFailedToStart
        }
        
        guard writer.startWriting() else {
            let err = writer.error as NSError?
            print("❌ domain:", err?.domain ?? "nil")
            print("❌ code:", err?.code ?? -1)
            print("❌ userInfo:", err?.userInfo ?? [:])
            print("❌ underlying:", err?.userInfo[NSUnderlyingErrorKey] ?? "nil")
            throw ExportError.writerFailedToStart(err?.userInfo.description ?? "unknown")
        }
        
        writer.startSession(atSourceTime: startTime)
        
        print("Processing Media")
        try await processMedia(
            reader: reader,
            videoOutput: videoOutput,
            audioOutput: audioOutput,
            writerInput: writerInput,
            audioWriterInput: audioWriterInput,
            writer: writer,
            adaptor: adaptor,
            sharpness: sharpness,
            contrast: contrast
        )
    }
    
    struct AVBox<T>: @unchecked Sendable {
        let value: T
    }
    
    func processMedia(
        reader: AVAssetReader,
        videoOutput: AVAssetReaderOutput,
        audioOutput: AVAssetReaderOutput?,
        writerInput: AVAssetWriterInput,
        audioWriterInput: AVAssetWriterInput?,
        writer: AVAssetWriter,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        sharpness: Float,
        contrast: Float
    ) async throws {
        let writerBox = AVBox(value: writer)
        let queue = DispatchQueue(label: "export.writer.queue")
        async let videoProcessing: Void = processVideo(
            queue: queue,
            reader: reader,
            videoOutput: videoOutput,
            writerInput: writerInput,
            writer: writer,
            adaptor: adaptor,
            sharpness: sharpness,
            contrast: contrast
        )

        async let audioProcessing: Void = processAudio(
            queue: queue,
            reader: reader,
            audioOutput: audioOutput,
            writerInput: audioWriterInput,
            writer: writer
        )

        do {
            _ = try await (videoProcessing, audioProcessing)
        } catch {
            if reader.status == .reading {
                reader.cancelReading()
            }
            if writer.status == .writing {
                writer.cancelWriting()
            }
            throw error
        }

        if let readerError = reader.error {
            throw readerError
        }
        if let writerError = writerBox.value.error {
            throw writerError
        }
        
        // MARK: Finish
        print("🏁 calling finishWriting, writer status:", writerBox.value.status.rawValue)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerBox.value.finishWriting {
                print("✅ finishWriting done, status:", writerBox.value.status.rawValue)
                print("❌ error:", writerBox.value.error ?? "none")
                continuation.resume()
            }
        }

        
        if let error = writer.error {
            throw error
        }
    }

    private func processVideo(
        queue: DispatchQueue,
        reader: AVAssetReader,
        videoOutput: AVAssetReaderOutput,
        writerInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        sharpness: Float,
        contrast: Float
    ) async throws {
        let readerBox = AVBox(value: reader)
        let writerBox = AVBox(value: writer)
        let inputBox = AVBox(value: writerInput)
        let videoOutputBox = AVBox(value: videoOutput)
        let adaptorBox = AVBox(value: adaptor)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false

            func resumeOnce(with result: Result<Void, Error>) {
                guard !didResume else { return }
                didResume = true

                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    if readerBox.value.status == .reading {
                        readerBox.value.cancelReading()
                    }
                    if writerBox.value.status == .writing {
                        writerBox.value.cancelWriting()
                    }
                    continuation.resume(throwing: error)
                }
            }

            writerInput.requestMediaDataWhenReady(on: queue) {
                guard !didResume else { return }

                while inputBox.value.isReadyForMoreMediaData {
                    if let readerError = readerBox.value.error {
                        resumeOnce(with: .failure(readerError))
                        return
                    }
                    if let writerError = writerBox.value.error {
                        resumeOnce(with: .failure(writerError))
                        return
                    }

                    guard let sampleBuffer = videoOutputBox.value.copyNextSampleBuffer() else {
                        print("📹 video exhausted, marking finished")
                        inputBox.value.markAsFinished()
                        resumeOnce(with: .success(()))
                        return
                    }

                    autoreleasepool {
                        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                            print("⚠️ no imageBuffer for sample, dropping frame")
                            return
                        }

                        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        print("📦 appending frame at:", presentationTime.seconds)

                        do {
                            let outputBuffer: CVPixelBuffer

                            if sharpness > 0 && contrast > 0 {
                                outputBuffer = try self.processFrame(
                                    inputBuffer: imageBuffer,
                                    sharpness: sharpness,
                                    contrast: contrast,
                                    pixelBufferPool: adaptorBox.value.pixelBufferPool
                                )
                            } else {
                                outputBuffer = imageBuffer
                            }

                            let ok = adaptorBox.value.append(outputBuffer, withPresentationTime: presentationTime)
                            print("append result:", ok, "writer error:", writerBox.value.error ?? "none")

                            if !ok {
                                let err = writerBox.value.error ?? ExportError.appendFailed
                                resumeOnce(with: .failure(err))
                            }
                        } catch {
                            resumeOnce(with: .failure(error))
                        }
                    }

                    if didResume {
                        return
                    }
                }
            }
        }
    }

    private func processAudio(
        queue: DispatchQueue,
        reader: AVAssetReader,
        audioOutput: AVAssetReaderOutput?,
        writerInput: AVAssetWriterInput?,
        writer: AVAssetWriter
    ) async throws {
        guard let audioOutput, let writerInput else {
            return
        }

        let readerBox = AVBox(value: reader)
        let writerBox = AVBox(value: writer)
        let audioOutputBox = AVBox(value: audioOutput)
        let audioInputBox = AVBox(value: writerInput)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false

            func resumeOnce(with result: Result<Void, Error>) {
                guard !didResume else { return }
                didResume = true

                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    if readerBox.value.status == .reading {
                        readerBox.value.cancelReading()
                    }
                    if writerBox.value.status == .writing {
                        writerBox.value.cancelWriting()
                    }
                    continuation.resume(throwing: error)
                }
            }

            audioInputBox.value.requestMediaDataWhenReady(on: queue) {
                guard !didResume else { return }

                while audioInputBox.value.isReadyForMoreMediaData {
                    if let readerError = readerBox.value.error {
                        resumeOnce(with: .failure(readerError))
                        return
                    }
                    if let writerError = writerBox.value.error {
                        resumeOnce(with: .failure(writerError))
                        return
                    }

                    guard let sampleBuffer = audioOutputBox.value.copyNextSampleBuffer() else {
                        print("🔊 audio exhausted, marking finished")
                        audioInputBox.value.markAsFinished()
                        resumeOnce(with: .success(()))
                        return
                    }

                    let ok = audioInputBox.value.append(sampleBuffer)
                    if !ok {
                        let err = writerBox.value.error ?? ExportError.appendFailed
                        resumeOnce(with: .failure(err))
                        return
                    }
                }
            }
        }
    }
    
    internal func getCGImage(from texture: MTLTexture) -> CGImage? {
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ]) else { return nil }
        let flipped = ciImage.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -ciImage.extent.height))
        
        let context = CIContext(mtlDevice: MetalContext.shared.device)
        return context.createCGImage(flipped, from: flipped.extent)
    }
    
    private func processFrame(
        inputBuffer: CVPixelBuffer,
        sharpness: Float,
        contrast: Float,
        pixelBufferPool: CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        guard let cgImage = getCG(from: inputBuffer) else {
            throw ExportError.cgImageCreationFailed
        }
        let outputCGImage: CGImage
        
        // MARK: here
        guard let texture = try MetalHelpers.getImageTexture(from: cgImage) else { throw ExportError.cgImageCreationFailed }
        
        let contrastTexture = try imageContrastBooster.boostContrast(for: texture, factor: contrast) ?? texture
        
        if let sharpened = try imageSharpener.sharpen(contrastTexture, sharpness: sharpness), let image = getCGImage(from: sharpened) {
            outputCGImage = image
        } else {
            outputCGImage = cgImage
        }
        
        guard let pool = pixelBufferPool else {
            throw ExportError.missingPixelBufferPool
        }
        
        var newBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &newBuffer)
        guard status == kCVReturnSuccess, let buffer = newBuffer else {
            throw ExportError.pixelBufferCreationFailed
        }
        
        try draw(cgImage: outputCGImage, into: buffer)
        return buffer
    }

    private func draw(cgImage: CGImage, into pixelBuffer: CVPixelBuffer) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ExportError.missingBaseAddress
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw ExportError.contextCreationFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    private func adjustedVideoSize(for naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = abs(rect.width)
        let height = abs(rect.height)
        // HEVC requires even dimensions
        return CGSize(
            width: floor(width / 2) * 2,
            height: floor(height / 2) * 2
        )
    }
    private func getCG(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
