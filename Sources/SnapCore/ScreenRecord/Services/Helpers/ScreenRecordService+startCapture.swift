//
//  ScreenRecordService+startCapture.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

import ScreenCaptureKit

extension ScreenRecordService {
    internal func startCapture(with filter: SCContentFilter) async throws {
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = showsCursor
        config.capturesAudio = capturesAudio
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        let output = StreamOutput()
        output.onScreenFrame = onScreenFrame
        output.onAudioFrame = onAudioFrame
        
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: videoQueue)
        if capturesAudio {
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
        }
        
        self.stream = stream
        self.streamOutput = output
        
        try await stream.startCapture()
    }
}
