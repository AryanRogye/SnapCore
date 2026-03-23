//
//  Exporter.swift
//  TestingSR
//
//  Created by Aryan Rogye on 3/19/26.
//

import AVFoundation
import AppKit

enum ExportError: Error {
    case noVideoTrack
    case cannotAddReaderOutput
    case cannotAddWriterInput
    case readerFailedToStart
    case writerFailedToStart
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
        let (reader, readerOutput) = try setupReader(
            asset: asset,
            selectedRange: selectedRange,
            videoTrack: videoTrack
        )

        try await setupWriter(
            reader: reader,
            readerOutput: readerOutput,
            outputURL: outputURL,
            videoTrack: videoTrack,
            startTime: startTime,
            sharpness: sharpness,
            contrast: contrast,
        )
        NSWorkspace.shared.open(outputURL)
        return outputURL
    }
    
    private func setupReader(
        asset: AVURLAsset,
        selectedRange: CMTimeRange,
        videoTrack: AVAssetTrack
    ) throws -> (AVAssetReader, AVAssetReaderOutput) {
        let reader = try AVAssetReader(asset: asset)
        
        /// set the readers time range to what the user has set
        reader.timeRange = selectedRange
        
        /// config for how video frames should be read
        let readerOutputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: readerOutputSettings
        )
        /// optimization
        readerOutput.alwaysCopiesSampleData = false
        
        guard reader.canAdd(readerOutput) else {
            throw ExportError.cannotAddReaderOutput
        }
        reader.add(readerOutput)
        
        return (reader, readerOutput)
    }
    
    private func setupWriter(
        reader: AVAssetReader,
        readerOutput: AVAssetReaderOutput,
        outputURL: URL,
        videoTrack: AVAssetTrack,
        startTime: CMTime,
        sharpness: Float,
        contrast: Float,
    ) async throws {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let outputSize = adjustedVideoSize(for: naturalSize, transform: preferredTransform)
        
        let originalBitrate = try await videoTrack.load(.estimatedDataRate)
        let targetBitrate = originalBitrate > 0 ? originalBitrate : 15_000_000
        
        let writerInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: outputSize.width,
            AVVideoHeightKey: outputSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: targetBitrate,
                AVVideoProfileLevelKey: "HEVC_Main_AutoLevel"
            ]
        ]
//        let writerInputSettings: [String: Any] = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey: outputSize.width,
//            AVVideoHeightKey: outputSize.height,
//            AVVideoCompressionPropertiesKey: [
//                AVVideoAverageBitRateKey: targetBitrate,
//                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
//            ]
//        ]
        
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
        
        guard reader.startReading() else {
            throw reader.error ?? ExportError.readerFailedToStart
        }
        
        guard writer.startWriting() else {
            throw writer.error ?? ExportError.writerFailedToStart
        }
        
        writer.startSession(atSourceTime: startTime)
        
        let queue = DispatchQueue(label: "export.writer.queue")
        try await processMedia(
            queue: queue,
            readerOutput: readerOutput,
            writerInput: writerInput,
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
        queue: DispatchQueue,
        readerOutput: AVAssetReaderOutput,
        writerInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        sharpness: Float,
        contrast: Float
    ) async throws {
        
        let writerBox = AVBox(value: writer)
        let inputBox = AVBox(value: writerInput)
        let outputBox = AVBox(value: readerOutput)
        let adaptorBox = AVBox(value: adaptor)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: queue) {
                while inputBox.value.isReadyForMoreMediaData {
                    guard let sampleBuffer = outputBox.value.copyNextSampleBuffer() else {
                        inputBox.value.markAsFinished()
                        
                        writerBox.value.finishWriting {
                            if let error = writerBox.value.error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                        return
                    }
                    
                    autoreleasepool {
                        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                            return
                        }
                        
                        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        
                        do {
                            let outputBuffer: CVPixelBuffer
                            
                            if sharpness > 0 {
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
                            if !ok {
                                let err = writerBox.value.error ?? ExportError.appendFailed
                                continuation.resume(throwing: err)
                            }
                        } catch {
                            continuation.resume(throwing: error)
                        }
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
        
        guard var cgImage = getCG(from: inputBuffer) else {
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
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
    private func getCG(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
