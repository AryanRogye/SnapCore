//
//  PlaybackImageCoordinator+Frame.swift
//  SnapCore
//
//  Created by Aryan Rogye on 3/22/26.
//

import CoreImage
import CoreMedia
import AVFoundation

#if os(iOS)
extension PlaybackImageCoordinator {
    /**
     * Function Converts a CVPixelBuffer to a CGImage
     */
    internal func getCG(
        from pixelBuffer: CVPixelBuffer
    ) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    
    /**
     * Public api to get the frame at the time,
     * this can be useful to display the frame in the
     * clip [  image  ] [  image  ] [  image  ]
     */
    public func frame(
        at time: CMTime
    ) -> CGImage? {
        guard let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: time,
            itemTimeForDisplay: nil
        ) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(
            ciImage,
            from: ciImage.extent
        )
    }

    @MainActor
    internal func refreshCurrentFrame(
        at time: CMTime,
        fallbackAsset: AVAsset? = nil
    ) {
        currentTime = CMTimeGetSeconds(time)

        if let pixelBuffer = videoOutput.copyPixelBuffer(
            forItemTime: time,
            itemTimeForDisplay: nil
        ) {
            processImage(pixelBuffer: pixelBuffer)
            return
        }

        guard let fallbackAsset else { return }

        let generator = AVAssetImageGenerator(asset: fallbackAsset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        do {
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            try processImage(cgImage: cgImage)
        } catch {
            print("frame refresh failed: \(error.localizedDescription)")
        }
    }
    
    public func frame(
        for url: URL,
        at seconds: Double
    ) async -> CGImage? {
        return await frameCache.frame(
            for: url,
            at: seconds
        )
    }
}


actor FrameCache {
    private var assets: [URL: AVURLAsset] = [:]
    private var durations: [URL: TimeInterval] = [:]
    private var generators: [URL: AVAssetImageGenerator] = [:]
    private let previewTolerance = CMTime(value: 1, timescale: 120)
    
    func frame(
        for url: URL,
        at seconds: TimeInterval
    ) async -> CGImage? {
        guard !Task.isCancelled else { return nil }
        
        let duration = await assetDuration(for: url)
        
        guard !Task.isCancelled else { return nil }
        
        let time = CMTime(
            seconds: clampedSampleTime(seconds, assetDuration: duration),
            preferredTimescale: 600
        )
        
        do {
            guard !Task.isCancelled else { return nil }
            return try generator(for: url).copyCGImage(at: time, actualTime: nil)
        } catch {
            guard !Task.isCancelled else { return nil }
            
            generators[url]?.cancelAllCGImageGeneration()
            generators[url] = nil
            assets[url] = nil
            durations[url] = nil
            
            guard !Task.isCancelled else { return nil }
            
            do {
                let refreshedDuration = await assetDuration(for: url)
                
                guard !Task.isCancelled else { return nil }
                
                let refreshedTime = CMTime(
                    seconds: clampedSampleTime(seconds, assetDuration: refreshedDuration),
                    preferredTimescale: 600
                )
                return try generator(for: url, refresh: true).copyCGImage(at: refreshedTime, actualTime: nil)
            } catch {
                print("preview frame generation failed:", error)
                return nil
            }
        }
    }
    
    private func generator(
        for url: URL,
        refresh: Bool = false
    ) -> AVAssetImageGenerator {
        if !refresh, let existing = generators[url] {
            return existing
        }
        
        let generator = makeGenerator(for: asset(for: url))
        generators[url] = generator
        return generator
    }
    
    private func asset(for url: URL) -> AVURLAsset {
        if let existing = assets[url] {
            return existing
        }
        
        let asset = AVURLAsset(url: url)
        assets[url] = asset
        return asset
    }
    
    private func assetDuration(for url: URL) async -> TimeInterval {
        if let existing = durations[url], existing.isFinite, existing > 0 {
            return existing
        }
        
        let asset = asset(for: url)
        let loadedDuration = (try? await asset.load(.duration)) ?? asset.duration
        let seconds = loadedDuration.seconds
        let safeDuration = seconds.isFinite ? max(seconds, 0) : 0
        durations[url] = safeDuration
        return safeDuration
    }
    
    private func makeGenerator(for asset: AVAsset) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = previewTolerance
        generator.requestedTimeToleranceAfter = previewTolerance
        return generator
    }
    
    private func clampedSampleTime(
        _ seconds: TimeInterval,
        assetDuration: TimeInterval
    ) -> TimeInterval {
        let safeSeconds = seconds.isFinite ? max(seconds, 0) : 0
        guard assetDuration.isFinite, assetDuration > 0 else {
            return safeSeconds
        }
        
        let padding = max(previewTolerance.seconds, 1.0 / 600.0)
        let safeStart = min(padding, assetDuration)
        let safeEnd = max(assetDuration - padding, safeStart)
        return min(max(safeSeconds, safeStart), safeEnd)
    }
}
#endif
