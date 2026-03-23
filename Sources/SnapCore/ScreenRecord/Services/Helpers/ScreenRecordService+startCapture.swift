//
//  ScreenRecordService+startCapture.swift
//  SnapCore
//
//  Created by Aryan Rogye on 10/2/25.
//

#if os(macOS)
import AVFoundation
import ScreenCaptureKit

extension ScreenRecordService {
    internal func startCapture(with filter: SCContentFilter) async throws {
        guard let display = filter.includedDisplays.first else { return }
        
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.showsCursor = showsCursor
        config.capturesAudio = capturesAudio
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.captureResolution = .best
        config.presenterOverlayPrivacyAlertSetting = .always
        config.colorSpaceName = CGColorSpace.displayP3
        config.queueDepth = 8
        
        (config.width, config.height) = self.calculateWidthAndHeightOfDisplay(display: display)
        
        config.scalesToFit = false
        config.preservesAspectRatio = true
        
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        let output = StreamOutput()
        attachOutput(output)
        
        try stream.addStreamOutput(
            output,
            type: .screen,
            sampleHandlerQueue: videoQueue
        )
        if capturesAudio {
            try stream.addStreamOutput(
                output,
                type: .audio,
                sampleHandlerQueue: audioQueue
            )
        }
        
        if let pendingRecordingOutputURL {
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = pendingRecordingOutputURL
            
            switch pendingRecordingOutputURL.pathExtension.lowercased() {
            case "mov":
                recordingConfig.outputFileType = .mov
            case "mp4", "m4v":
                recordingConfig.outputFileType = .mp4
            default:
                break
            }
            
            let recordingOutput = SCRecordingOutput(
                configuration: recordingConfig,
                delegate: self
            )
            try stream.addRecordingOutput(recordingOutput)
            recordingOutputStorage = recordingOutput
        }
        
        self.stream = stream
        self.streamOutput = output
        
        try await stream.startCapture()
    }
    
    internal func attachOutput(_ output: StreamOutput) {
        streamOutput = output
        
        screenFrameTask = Task { [weak self] in
            for await frame in output.screenFrames {
                await self?.onScreenFrame?(frame)
            }
        }
        
        audioFrameTask = Task { [weak self] in
            for await frame in output.audioFrames {
                await self?.onAudioFrame?(frame)
            }
        }
    }
}

#endif
