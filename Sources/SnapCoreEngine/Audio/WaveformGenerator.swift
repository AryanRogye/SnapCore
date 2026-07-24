//
//  WaveformGenerator.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/5/26.
//

import Foundation
import AVFoundation
import Accelerate


// MARK: - Peak Generator
public struct WaveformPeak {
    public let minimum: Float
    public let maximum: Float
    
    public init(minimum: Float, maximum: Float) {
        self.minimum = minimum
        self.maximum = maximum
    }
    
    public var amplitude: Float {
        return maximum - minimum
    }
}

// MARK: - Peak
public enum WaveformPeakGenerator {
    @concurrent
    public static func generateWaveform(
        from url: URL,
        startTime: TimeInterval = 0,
        endTime: TimeInterval? = nil,
        sampleCount: Int = 500
    ) async -> [[WaveformPeak]] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        guard sampleCount > 0 else { return [] }
        
        let totalFrames = AVAudioFramePosition(audioFile.length)
        let sampleRate = audioFile.processingFormat.sampleRate
        
        let requestedStartFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let requestedEndFrame: AVAudioFramePosition = {
            if let endTime {
                return AVAudioFramePosition(max(0, endTime) * sampleRate)
            }
            return totalFrames
        }()
        
        let startFrame = min(max(0, requestedStartFrame), totalFrames)
        let endFrame = min(max(startFrame, requestedEndFrame), totalFrames)
        guard endFrame > startFrame else { return [] }
        
        audioFile.framePosition = startFrame
        
        let targetFrameCount = endFrame - startFrame
        let rawFramesPerBuffer = max(1, targetFrameCount / Int64(sampleCount))
        let framesPerBuffer = AVAudioFrameCount(min(rawFramesPerBuffer, Int64(UInt32.max)))
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: framesPerBuffer
        ) else { return [] }
        
        let channelCount = min(Int(audioFile.processingFormat.channelCount), 2)
        guard channelCount > 0 else { return [] }
        
        var channels = Array(repeating: [WaveformPeak](), count: channelCount)
        for index in channels.indices {
            channels[index].reserveCapacity(sampleCount)
        }
        
        do {
            while audioFile.framePosition < endFrame {
                let framesLeft = endFrame - audioFile.framePosition
                let clampedFramesLeft = min(framesLeft, AVAudioFramePosition(UInt32.max))
                let framesToRead = min(AVAudioFrameCount(clampedFramesLeft), framesPerBuffer)
                
                try audioFile.read(into: buffer, frameCount: framesToRead)
                guard let floatChannelData = buffer.floatChannelData, buffer.frameLength > 0 else { break }
                
                for channel in 0..<channelCount {
                    let channelData = floatChannelData[channel]
                    var minimum: Float = 0
                    var maximum: Float = 0
                    
                    vDSP_minv(channelData, 1, &minimum, vDSP_Length(buffer.frameLength))
                    vDSP_maxv(channelData, 1, &maximum, vDSP_Length(buffer.frameLength))
                    
                    channels[channel].append(WaveformPeak(minimum: minimum, maximum: maximum))
                }
                
                if channels.allSatisfy({ $0.count >= sampleCount }) { break }
            }
        } catch {
            print("Error reading audio file: \(error)")
        }
        
        let normalized = normalize(channels)
        return normalized.map { resample($0, to: sampleCount) }
    }
    
    private static func normalize(_ channels: [[WaveformPeak]]) -> [[WaveformPeak]] {
        let maxMagnitude = channels
            .flatMap { $0 }
            .reduce(Float(0)) { partial, peak in
                max(partial, abs(peak.minimum), abs(peak.maximum))
            }
        
        guard maxMagnitude > 0 else { return channels }
        
        return channels.map { peaks in
            peaks.map {
                WaveformPeak(
                    minimum: $0.minimum / maxMagnitude,
                    maximum: $0.maximum / maxMagnitude
                )
            }
        }
    }
    
    private static func resample(_ peaks: [WaveformPeak], to sampleCount: Int) -> [WaveformPeak] {
        guard sampleCount > 0 else { return [] }
        guard !peaks.isEmpty else { return [] }
        guard peaks.count != sampleCount else { return peaks }
        guard sampleCount > 1 else { return [peaks[0]] }
        guard peaks.count > 1 else { return Array(repeating: peaks[0], count: sampleCount) }
        
        let scale = CGFloat(peaks.count) / CGFloat(sampleCount)
        
        return (0..<sampleCount).map { index in
            let start = Int(CGFloat(index) * scale)
            let end = min(
                peaks.count,
                max(start + 1, Int(CGFloat(index + 1) * scale))
            )
            let slice = peaks[start..<end]
            
            return WaveformPeak(
                minimum: slice.map(\.minimum).min() ?? 0,
                maximum: slice.map(\.maximum).max() ?? 0
            )
        }
    }
}

// MARK: - Signed Generator
public enum SignedWaveformGenerator {
    public static func generateWaveform(
        from url: URL,
        startTime: TimeInterval = 0,
        endTime: TimeInterval? = nil,
        sampleCount: Int = 500
    ) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        guard sampleCount > 0 else { return [] }
        
        let totalFrames = AVAudioFramePosition(audioFile.length)
        let sampleRate = audioFile.processingFormat.sampleRate
        
        let requestedStartFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let requestedEndFrame: AVAudioFramePosition = {
            if let endTime {
                return AVAudioFramePosition(max(0, endTime) * sampleRate)
            }
            return totalFrames
        }()
        
        let startFrame = min(max(0, requestedStartFrame), totalFrames)
        let endFrame = min(max(startFrame, requestedEndFrame), totalFrames)
        guard endFrame > startFrame else { return [] }
        
        audioFile.framePosition = startFrame
        
        let targetFrameCount = endFrame - startFrame
        let rawFramesPerBuffer = max(1, targetFrameCount / Int64(sampleCount))
        let framesPerBuffer = AVAudioFrameCount(min(rawFramesPerBuffer, Int64(UInt32.max)))
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: framesPerBuffer
        ) else { return [] }
        
        var waveform: [Float] = []
        waveform.reserveCapacity(sampleCount)
        let channelCount = Int(audioFile.processingFormat.channelCount)
        
        do {
            while audioFile.framePosition < endFrame {
                let framesLeft = endFrame - audioFile.framePosition
                let clampedFramesLeft = min(framesLeft, AVAudioFramePosition(UInt32.max))
                let framesToRead = min(AVAudioFrameCount(clampedFramesLeft), framesPerBuffer)
                
                try audioFile.read(into: buffer, frameCount: framesToRead)
                guard let floatChannelData = buffer.floatChannelData, buffer.frameLength > 0 else { break }
                
                var chunkMin: Float = 0
                var chunkMax: Float = 0
                
                for channel in 0..<channelCount {
                    let channelData = floatChannelData[channel]
                    var channelMin: Float = 0
                    var channelMax: Float = 0
                    
                    vDSP_minv(channelData, 1, &channelMin, vDSP_Length(buffer.frameLength))
                    vDSP_maxv(channelData, 1, &channelMax, vDSP_Length(buffer.frameLength))
                    
                    chunkMin = min(chunkMin, channelMin)
                    chunkMax = max(chunkMax, channelMax)
                }
                
                waveform.append(abs(chunkMin) > abs(chunkMax) ? chunkMin : chunkMax)
                
                if waveform.count >= sampleCount { break }
            }
        } catch {
            print("Error reading audio file: \(error)")
        }
        
        if let maxMagnitude = waveform.map(abs).max(), maxMagnitude > 0 {
            return resample(waveform.map { $0 / maxMagnitude }, to: sampleCount)
        }
        
        return resample(waveform, to: sampleCount)
    }
    
    private static func resample(_ samples: [Float], to sampleCount: Int) -> [Float] {
        guard sampleCount > 0 else { return [] }
        guard !samples.isEmpty else { return [] }
        guard samples.count != sampleCount else { return samples }
        guard sampleCount > 1 else { return [samples[0]] }
        guard samples.count > 1 else { return Array(repeating: samples[0], count: sampleCount) }
        
        let scale = Float(samples.count - 1) / Float(sampleCount - 1)
        
        return (0..<sampleCount).map { index in
            let sourcePosition = Float(index) * scale
            let lowerIndex = Int(sourcePosition)
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = sourcePosition - Float(lowerIndex)
            
            return samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
        }
    }
}

// MARK: - Generator
public enum WaveformGenerator {
    public static func generateWaveform(
        from url: URL,
        startTime: TimeInterval = 0,
        endTime: TimeInterval? = nil,
        sampleCount: Int = 500
    ) async -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }
        guard sampleCount > 0 else { return [] }
        
        let totalFrames = AVAudioFramePosition(audioFile.length)
        let sampleRate = audioFile.processingFormat.sampleRate
        
        let requestedStartFrame = AVAudioFramePosition(max(0, startTime) * sampleRate)
        let requestedEndFrame: AVAudioFramePosition = {
            if let endTime {
                return AVAudioFramePosition(max(0, endTime) * sampleRate)
            }
            return totalFrames
        }()
        
        let startFrame = min(max(0, requestedStartFrame), totalFrames)
        let endFrame = min(max(startFrame, requestedEndFrame), totalFrames)
        guard endFrame > startFrame else { return [] }
        
        audioFile.framePosition = startFrame
        
        let targetFrameCount = endFrame - startFrame
        let rawFramesPerBuffer = max(1, targetFrameCount / Int64(sampleCount))
        let framesPerBuffer = AVAudioFrameCount(min(rawFramesPerBuffer, Int64(UInt32.max)))
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: framesPerBuffer
        ) else { return [] }
        
        var waveform: [Float] = []
        waveform.reserveCapacity(sampleCount)
        let channelCount = Int(audioFile.processingFormat.channelCount)
        
        do {
            while audioFile.framePosition < endFrame {
                let framesLeft = endFrame - audioFile.framePosition
                let clampedFramesLeft = min(framesLeft, AVAudioFramePosition(UInt32.max))
                let framesToRead = min(AVAudioFrameCount(clampedFramesLeft), framesPerBuffer)
                
                try audioFile.read(into: buffer, frameCount: framesToRead)
                guard let floatChannelData = buffer.floatChannelData, buffer.frameLength > 0 else { break }
                
                var binMax: Float = 0
                
                for channel in 0..<channelCount {
                    let channelData = floatChannelData[channel]
                    var channelPeak: Float = 0
                    
                    vDSP_maxmgv(channelData, 1, &channelPeak, vDSP_Length(buffer.frameLength))
                    binMax = max(binMax, channelPeak)
                }
                
                waveform.append(binMax)
                
                if waveform.count >= sampleCount { break }
            }
        } catch {
            print("Error reading audio file: \(error)")
        }
        
        if let maxVal = waveform.max(), maxVal > 0 {
            let normalized = waveform.map { $0 / maxVal }
            return resample(normalized, to: sampleCount)
        }
        
        return resample(waveform, to: sampleCount)
    }
    
    private static func resample(_ samples: [Float], to sampleCount: Int) -> [Float] {
        guard sampleCount > 0 else { return [] }
        guard !samples.isEmpty else { return [] }
        guard samples.count != sampleCount else { return samples }
        guard sampleCount > 1 else { return [samples[0]] }
        guard samples.count > 1 else { return Array(repeating: samples[0], count: sampleCount) }
        
        let scale = Float(samples.count - 1) / Float(sampleCount - 1)
        
        return (0..<sampleCount).map { index in
            let sourcePosition = Float(index) * scale
            let lowerIndex = Int(sourcePosition)
            let upperIndex = min(lowerIndex + 1, samples.count - 1)
            let fraction = sourcePosition - Float(lowerIndex)
            
            return samples[lowerIndex] + (samples[upperIndex] - samples[lowerIndex]) * fraction
        }
    }
}
