//
//  WaveformGenerator.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/5/26.
//

import Foundation
import AVFoundation
import Accelerate

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
