import CoreMedia
import CoreVideo
import XCTest
@testable import SnapCore

final class LiveMediaEncoderTests: XCTestCase {
    func testFirstEncodedFrameEmitsConfigurationBeforeVideo() throws {
        var pixelBuffer: CVPixelBuffer?
        XCTAssertEqual(
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                640,
                360,
                kCVPixelFormatType_32BGRA,
                [
                    kCVPixelBufferIOSurfacePropertiesKey: [:],
                ] as CFDictionary,
                &pixelBuffer
            ),
            kCVReturnSuccess
        )
        let imageBuffer = try XCTUnwrap(pixelBuffer)

        var formatDescription: CMVideoFormatDescription?
        XCTAssertEqual(
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: imageBuffer,
                formatDescriptionOut: &formatDescription
            ),
            noErr
        )

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        XCTAssertEqual(
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: imageBuffer,
                formatDescription: try XCTUnwrap(formatDescription),
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            ),
            noErr
        )

        let configurationExpectation = expectation(description: "video configuration")
        let frameExpectation = expectation(description: "video frame")
        let encoder = LiveMediaEncoder(
            configuration: .init(
                framesPerSecond: 30,
                averageBitRate: 2_000_000,
                keyFrameInterval: 30
            )
        )
        let packetKinds = PacketKinds()
        encoder.onPacket = { packet in
            packetKinds.append(packet.kind)
            switch packet.kind {
            case .videoConfiguration:
                configurationExpectation.fulfill()
            case .videoFrame:
                frameExpectation.fulfill()
            case .audioConfiguration, .audioFrame:
                break
            }
        }

        encoder.encodeVideo(try XCTUnwrap(sampleBuffer))
        wait(for: [configurationExpectation, frameExpectation], timeout: 5)
        encoder.stop()

        XCTAssertEqual(
            Array(packetKinds.snapshot().prefix(2)),
            [.videoConfiguration, .videoFrame]
        )
    }
}

private final class PacketKinds: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [LiveMediaPacketKind] = []

    func append(_ kind: LiveMediaPacketKind) {
        lock.withLock { storage.append(kind) }
    }

    func snapshot() -> [LiveMediaPacketKind] {
        lock.withLock { storage }
    }
}
