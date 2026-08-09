import AudioToolbox
import CoreMedia
import Foundation
import OSLog
import VideoToolbox

private let liveMediaLogger = Logger(
    subsystem: "com.aryanrogye.SnapCore",
    category: "LiveMedia"
)

/// The media records emitted by ``LiveMediaEncoder``.
public enum LiveMediaPacketKind: UInt8, Sendable {
    case videoConfiguration = 1
    case videoFrame = 2
    case audioConfiguration = 3
    case audioFrame = 4
}

/// One timestamped record ready for an encrypted live transport.
public struct LiveMediaPacket: @unchecked Sendable {
    public let kind: LiveMediaPacketKind
    public let timestampMilliseconds: UInt64
    public let isKeyFrame: Bool
    public let payload: Data

    public init(
        kind: LiveMediaPacketKind,
        timestampMilliseconds: UInt64,
        isKeyFrame: Bool = false,
        payload: Data
    ) {
        self.kind = kind
        self.timestampMilliseconds = timestampMilliseconds
        self.isKeyFrame = isKeyFrame
        self.payload = payload
    }
}

/// Hardware-backed H.264 video and PCM audio encoding tuned for interactive streaming.
///
/// Video is emitted as Annex-B H.264. Audio is emitted as signed 16-bit,
/// little-endian, interleaved PCM so receivers can play it without another
/// latency-producing codec stage.
public final class LiveMediaEncoder: @unchecked Sendable {
    public struct Configuration: Sendable, Equatable {
        public var framesPerSecond: Int
        public var averageBitRate: Int
        public var keyFrameInterval: Int

        public init(
            framesPerSecond: Int = 60,
            averageBitRate: Int = 10_000_000,
            keyFrameInterval: Int = 60
        ) {
            self.framesPerSecond = framesPerSecond
            self.averageBitRate = averageBitRate
            self.keyFrameInterval = keyFrameInterval
        }
    }

    public var onPacket: (@Sendable (LiveMediaPacket) -> Void)?
    public var onError: (@Sendable (String) -> Void)?

    private var configuration: Configuration
    private let queue = DispatchQueue(label: "com.snapcore.live-media-encoder", qos: .userInteractive)
    private var compressionSession: VTCompressionSession?
    private var videoDimensions: (width: Int, height: Int)?
    private var videoRotationDegrees: UInt16 = 0
    private var lastVideoConfiguration: Data?
    private var audioDescription: AudioStreamBasicDescription?
    private var stopped = false
    private var encodedVideoFrameCount = 0

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    deinit {
        stop()
    }

    public func encodeVideo(
        _ sampleBuffer: CMSampleBuffer,
        rotationDegrees: UInt16 = 0
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        encodeVideo(
            imageBuffer,
            timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            rotationDegrees: rotationDegrees
        )
    }

    public func encodeVideo(
        _ imageBuffer: CVPixelBuffer,
        timestamp: CMTime,
        rotationDegrees: UInt16 = 0
    ) {
        let retained = RetainedPixelBuffer(imageBuffer)
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            if self.videoDimensions == nil {
                liveMediaLogger.info("Received retained video pixel buffer")
            }
            self.encode(
                retained.value,
                timestamp: timestamp,
                rotationDegrees: rotationDegrees
            )
        }
    }

    public func encodeAudio(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let retained = RetainedSampleBuffer(sampleBuffer)
        queue.async { [weak self] in
            guard let self, !self.stopped else { return }
            self.encodePCM(retained.value)
        }
    }

    public func stop() {
        queue.sync { [self] in
            guard !stopped else { return }
            stopped = true
            if let compressionSession {
                VTCompressionSessionCompleteFrames(
                    compressionSession,
                    untilPresentationTimeStamp: .invalid
                )
                VTCompressionSessionInvalidate(compressionSession)
            }
            compressionSession = nil
            videoDimensions = nil
            lastVideoConfiguration = nil
            audioDescription = nil
            encodedVideoFrameCount = 0
        }
    }

    /// Makes a previously stopped encoder ready for a new live session.
    public func restart() {
        queue.sync { [self] in
            guard stopped else { return }
            compressionSession = nil
            videoDimensions = nil
            lastVideoConfiguration = nil
            audioDescription = nil
            encodedVideoFrameCount = 0
            stopped = false
        }
    }

    /// Applies a new live encoding preset. The next submitted frame starts a
    /// fresh H.264 session and emits matching SPS/PPS before its keyframe.
    public func updateConfiguration(_ configuration: Configuration) {
        queue.sync { [self] in
            guard self.configuration != configuration else { return }
            self.configuration = configuration
            if let compressionSession {
                VTCompressionSessionCompleteFrames(
                    compressionSession,
                    untilPresentationTimeStamp: .invalid
                )
                VTCompressionSessionInvalidate(compressionSession)
            }
            compressionSession = nil
            videoDimensions = nil
            lastVideoConfiguration = nil
            encodedVideoFrameCount = 0
        }
    }

    private func encode(
        _ imageBuffer: CVPixelBuffer,
        timestamp: CMTime,
        rotationDegrees: UInt16
    ) {
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let dimensions = (width, height)

        if videoDimensions?.width != dimensions.0 ||
            videoDimensions?.height != dimensions.1 ||
            videoRotationDegrees != rotationDegrees ||
            compressionSession == nil {
            createCompressionSession(
                width: width,
                height: height,
                rotationDegrees: rotationDegrees
            )
        }

        guard let compressionSession else { return }
        let duration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(configuration.framesPerSecond, 1))
        )
        let status = VTCompressionSessionEncodeFrame(
            compressionSession,
            imageBuffer: imageBuffer,
            presentationTimeStamp: timestamp,
            duration: duration,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        if status != noErr {
            onError?("H.264 encoder rejected a frame (OSStatus \(status)).")
        }
    }

    private func createCompressionSession(
        width: Int,
        height: Int,
        rotationDegrees: UInt16
    ) {
        if let compressionSession {
            VTCompressionSessionCompleteFrames(
                compressionSession,
                untilPresentationTimeStamp: .invalid
            )
            VTCompressionSessionInvalidate(compressionSession)
        }

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: liveMediaCompressionCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            onError?("Could not create the hardware H.264 encoder (OSStatus \(status)).")
            compressionSession = nil
            return
        }
        liveMediaLogger.info("Created H.264 encoder for \(width)x\(height), rotation \(rotationDegrees)")

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: configuration.framesPerSecond as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: configuration.averageBitRate as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: configuration.keyFrameInterval as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 1 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxFrameDelayCount, value: 0 as CFNumber)

        let bytesPerSecond = max(configuration.averageBitRate / 8, 1)
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_DataRateLimits,
            value: [bytesPerSecond * 2, 1] as CFArray
        )
        VTCompressionSessionPrepareToEncodeFrames(session)

        compressionSession = session
        videoDimensions = (width, height)
        videoRotationDegrees = rotationDegrees
        lastVideoConfiguration = nil
    }

    fileprivate func didEncode(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr,
              let sampleBuffer,
              CMSampleBufferDataIsReady(sampleBuffer) else {
            if status != noErr {
                onError?("H.264 encoding failed (OSStatus \(status)).")
            }
            return
        }

        let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[CFString: Any]]
        // VideoToolbox commonly includes NotSync on every sample and stores
        // `false` on an IDR. Testing only for key presence incorrectly labels
        // those IDRs as delta frames and prevents SPS/PPS from ever being sent.
        let isNotSync = attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
        let isKeyFrame = !isNotSync
        encodedVideoFrameCount += 1
        if encodedVideoFrameCount == 1 || encodedVideoFrameCount % 120 == 0 {
            liveMediaLogger.info("Encoded video frame \(self.encodedVideoFrameCount), key=\(isKeyFrame)")
        }

        if isKeyFrame,
           let format = CMSampleBufferGetFormatDescription(sampleBuffer),
           let configurationPacket = makeVideoConfiguration(from: format),
           configurationPacket != lastVideoConfiguration {
            lastVideoConfiguration = configurationPacket
            liveMediaLogger.info("Emitting H.264 configuration, \(configurationPacket.count) bytes")
            onPacket?(
                LiveMediaPacket(
                    kind: .videoConfiguration,
                    timestampMilliseconds: timestampMilliseconds(for: sampleBuffer),
                    isKeyFrame: true,
                    payload: configurationPacket
                )
            )
        }

        guard let annexB = makeAnnexBData(from: sampleBuffer) else { return }
        onPacket?(
            LiveMediaPacket(
                kind: .videoFrame,
                timestampMilliseconds: timestampMilliseconds(for: sampleBuffer),
                isKeyFrame: isKeyFrame,
                payload: annexB
            )
        )
    }

    private func makeVideoConfiguration(
        from format: CMFormatDescription
    ) -> Data? {
        var parameterSetCount = 0
        var headerLength: Int32 = 0
        guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            format,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &headerLength
        ) == noErr,
              parameterSetCount >= 2 else {
            return nil
        }

        var sets: [Data] = []
        for index in 0..<2 {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                format,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            ) == noErr,
                  let pointer,
                  size <= Int(UInt16.max) else {
                return nil
            }
            sets.append(Data(bytes: pointer, count: size))
        }

        guard let dimensions = videoDimensions else { return nil }
        var result = Data()
        result.appendBigEndian(UInt16(clamping: dimensions.width))
        result.appendBigEndian(UInt16(clamping: dimensions.height))
        result.appendBigEndian(videoRotationDegrees)
        for set in sets {
            result.appendBigEndian(UInt16(set.count))
            result.append(set)
        }
        return result
    }

    private func makeAnnexBData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        var totalLength = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &totalLength,
            dataPointerOut: &pointer
        ) == noErr,
              let pointer else {
            return nil
        }

        let bytes = UnsafeRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
        var offset = 0
        var result = Data()
        result.reserveCapacity(totalLength + 32)
        while offset + 4 <= totalLength {
            let length = Int(bytes[offset]) << 24 |
                Int(bytes[offset + 1]) << 16 |
                Int(bytes[offset + 2]) << 8 |
                Int(bytes[offset + 3])
            offset += 4
            guard length > 0, offset + length <= totalLength else { return nil }
            result.append(contentsOf: [0, 0, 0, 1])
            result.append(bytes + offset, count: length)
            offset += length
        }
        return offset == totalLength ? result : nil
    }

    private func encodePCM(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
                formatDescription
              )?.pointee,
              basicDescription.mFormatID == kAudioFormatLinearPCM else {
            onError?("The capture source supplied an unsupported audio format.")
            return
        }

        let channelCount = max(1, min(Int(basicDescription.mChannelsPerFrame), 2))
        let sampleRate = UInt32(basicDescription.mSampleRate.rounded())
        if audioDescription?.mSampleRate != basicDescription.mSampleRate ||
            audioDescription?.mChannelsPerFrame != UInt32(channelCount) ||
            audioDescription?.mFormatFlags != basicDescription.mFormatFlags ||
            audioDescription?.mBitsPerChannel != basicDescription.mBitsPerChannel {
            audioDescription = basicDescription
            var configuration = Data()
            configuration.appendBigEndian(sampleRate)
            configuration.append(UInt8(channelCount))
            configuration.append(1) // PCM signed 16-bit little-endian.
            onPacket?(
                LiveMediaPacket(
                    kind: .audioConfiguration,
                    timestampMilliseconds: timestampMilliseconds(for: sampleBuffer),
                    payload: configuration
                )
            )
        }

        var requiredSize = 0
        var retainedBlockBuffer: CMBlockBuffer?
        let sizingStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &retainedBlockBuffer
        )
        guard sizingStatus == noErr, requiredSize > 0 else { return }

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        let bufferList = storage.assumingMemoryBound(to: AudioBufferList.self)
        retainedBlockBuffer = nil
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList,
            bufferListSize: requiredSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &retainedBlockBuffer
        ) == noErr else {
            return
        }

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return }

        let isPlanar = basicDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let bytesPerSample = max(Int(basicDescription.mBitsPerChannel / 8), 1)
        let sourceChannels = max(Int(basicDescription.mChannelsPerFrame), 1)
        var pcm = Data(count: frameCount * channelCount * MemoryLayout<Int16>.size)
        pcm.withUnsafeMutableBytes { output in
            let samples = output.bindMemory(to: Int16.self)
            for frame in 0..<frameCount {
                for channel in 0..<channelCount {
                    let sourceChannel = min(channel, sourceChannels - 1)
                    let bufferIndex = isPlanar ? min(sourceChannel, buffers.count - 1) : 0
                    guard bufferIndex >= 0,
                          let data = buffers[bufferIndex].mData else {
                        continue
                    }
                    let byteOffset = isPlanar
                        ? frame * bytesPerSample
                        : (frame * sourceChannels + sourceChannel) * bytesPerSample
                    let value = Self.normalizedSample(
                        at: data,
                        offset: byteOffset,
                        description: basicDescription
                    )
                    let clipped = max(-1.0, min(value, 1.0))
                    samples[frame * channelCount + channel] = Int16(
                        (clipped * Float(Int16.max)).rounded()
                    ).littleEndian
                }
            }
        }

        onPacket?(
            LiveMediaPacket(
                kind: .audioFrame,
                timestampMilliseconds: timestampMilliseconds(for: sampleBuffer),
                payload: pcm
            )
        )
    }

    private static func normalizedSample(
        at pointer: UnsafeMutableRawPointer,
        offset: Int,
        description: AudioStreamBasicDescription
    ) -> Float {
        let isFloat = description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let isSigned = description.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0
        switch (isFloat, description.mBitsPerChannel) {
        case (true, 32):
            return pointer.load(fromByteOffset: offset, as: Float.self)
        case (true, 64):
            return Float(pointer.load(fromByteOffset: offset, as: Double.self))
        case (false, 16) where isSigned:
            let value = Int16(littleEndian: pointer.load(fromByteOffset: offset, as: Int16.self))
            return Float(value) / Float(Int16.max)
        case (false, 32) where isSigned:
            let value = Int32(littleEndian: pointer.load(fromByteOffset: offset, as: Int32.self))
            return Float(value) / Float(Int32.max)
        case (false, 8):
            let value = pointer.load(fromByteOffset: offset, as: UInt8.self)
            return (Float(value) - 128) / 127
        default:
            return 0
        }
    }

    private func timestampMilliseconds(for sampleBuffer: CMSampleBuffer) -> UInt64 {
        let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        return UInt64(seconds * 1_000)
    }
}

private let liveMediaCompressionCallback: VTCompressionOutputCallback = {
    reference, _, status, _, sampleBuffer in
    guard let reference else { return }
    Unmanaged<LiveMediaEncoder>
        .fromOpaque(reference)
        .takeUnretainedValue()
        .didEncode(status: status, sampleBuffer: sampleBuffer)
}

private final class RetainedPixelBuffer: @unchecked Sendable {
    let value: CVPixelBuffer
    init(_ value: CVPixelBuffer) { self.value = value }
}

private final class RetainedSampleBuffer: @unchecked Sendable {
    let value: CMSampleBuffer
    init(_ value: CMSampleBuffer) { self.value = value }
}

private extension Data {
    mutating func appendBigEndian<T: FixedWidthInteger>(_ value: T) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }
}
