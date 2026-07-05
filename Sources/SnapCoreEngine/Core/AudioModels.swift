//
//  AudioModels.swift
//  SnapCore
//
//  Created by Aryan Rogye on 7/4/26.
//

import Foundation
import AVFoundation

@Observable
public final class AudioInfo: Sendable {
    public var url: URL?
    public var start: Double          // normalized trim start
    public var end: Double            // normalized trim end
    public var timelineStart: Double  // seconds on timeline
    public var volume: CGFloat
    public var duration: Double
    
    public init(
        url: URL? = nil,
        start: Double,
        end: Double,
        timelineStart: Double,
        volume: CGFloat,
        duration: Double
    ) {
        self.url = url
        self.start = start
        self.end = end
        self.timelineStart = timelineStart
        self.volume = volume
        self.duration = duration
    }
    
    public static func createAudioInfo(from url: URL?) async throws -> AudioInfo {
        guard let url else {
            throw AudioError.invalidURL
        }
        
        return .init(
            url: url,
            // the engine internally sets itself to start at 0 and end at 1
            start: 0,
            end: 1.0,
            timelineStart: 0,
            volume: 1.0,
            duration: try await Self.loadDuration(from: url)
        )
    }
    
    
    private static func loadDuration(from url: URL) async throws -> Double {
        // creating a AVURLAsset from url
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds
        } catch {
            throw AudioError.failedToLoadDuration(url)
        }
    }
}


public enum AudioError: Error, LocalizedError {
    case invalidURL
    case failedToLoadDuration(URL)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .failedToLoadDuration(let url):
            "Failed to load duration for \(url.path)"
        }
    }
}
