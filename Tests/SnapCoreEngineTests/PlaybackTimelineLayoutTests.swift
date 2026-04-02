import XCTest
@testable import SnapCoreEngine

final class PlaybackTimelineLayoutTests: XCTestCase {
    func testResolvePrimaryVideoTrimsEarlierClipAtNextClipStart() {
        let intervals = [
            PlaybackTimelineInterval(index: 0, start: 0, end: 5),
            PlaybackTimelineInterval(index: 1, start: 3, end: 7),
            PlaybackTimelineInterval(index: 2, start: 8, end: 10),
        ]

        let resolved = PlaybackTimelineLayout.resolvePrimaryVideo(intervals)

        XCTAssertEqual(
            resolved,
            [
                PlaybackTimelineInterval(index: 0, start: 0, end: 3),
                PlaybackTimelineInterval(index: 1, start: 3, end: 7),
                PlaybackTimelineInterval(index: 2, start: 8, end: 10),
            ]
        )
    }

    func testResolvePrimaryVideoKeepsLatestClipWhenStartsMatch() {
        let intervals = [
            PlaybackTimelineInterval(index: 0, start: 0, end: 5),
            PlaybackTimelineInterval(index: 1, start: 0, end: 3),
        ]

        let resolved = PlaybackTimelineLayout.resolvePrimaryVideo(intervals)

        XCTAssertEqual(
            resolved,
            [
                PlaybackTimelineInterval(index: 1, start: 0, end: 3),
            ]
        )
    }

    func testAssignAudioLanesStacksOverlapsAndReusesFinishedLane() {
        let intervals = [
            PlaybackTimelineInterval(index: 0, start: 0, end: 5),
            PlaybackTimelineInterval(index: 1, start: 1, end: 3),
            PlaybackTimelineInterval(index: 2, start: 4, end: 6),
            PlaybackTimelineInterval(index: 3, start: 6, end: 8),
        ]

        let lanes = PlaybackTimelineLayout.assignAudioLanes(intervals)

        XCTAssertEqual(lanes.count, 2)
        XCTAssertEqual(
            lanes[0],
            [
                PlaybackTimelineInterval(index: 0, start: 0, end: 5),
                PlaybackTimelineInterval(index: 3, start: 6, end: 8),
            ]
        )
        XCTAssertEqual(
            lanes[1],
            [
                PlaybackTimelineInterval(index: 1, start: 1, end: 3),
                PlaybackTimelineInterval(index: 2, start: 4, end: 6),
            ]
        )
    }
}
