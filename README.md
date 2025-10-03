# SnapCore

SnapCore is a tiny Swift package for macOS that provides:

- Screenshot capture (returns `CGImage`)
- Screen recording (delivers `CMSampleBuffer` video/audio frames)

- Build: `swift build`
- Test: `swift test`

Note: Real capture and recording require macOS Screen Recording permission. Tests use mocks to avoid prompts.

### Requirements

- macOS 14+
- Swift 6
- ScreenCaptureKit (built-in on macOS 13+)

Swift 6 safe: APIs use modern concurrency annotations; frame types used across closures are marked as `@unchecked Sendable` where appropriate.

## Installation

Swift Package Manager (Git dependency):

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/AryanRogye/SnapCore.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SnapCore", package: "SnapCore")
        ]
    )
]
```

Local development alternative:

```swift
.package(path: "../SnapCore")
```

## Screenshots

```swift
import AppKit
import SnapCore

let screenshots = ScreenshotService()

// 1) Check permission (macOS Screen Recording)
guard screenshots.hasScreenshotPermission() else {
    // Prompt user to enable Screen Recording in System Settings,
    // then relaunch your app.
    fatalError("Screen Recording permission required")
}

// 2) Capture the active display as CGImage
if let image = await screenshots.takeScreenshot() {
    // use CGImage (save to disk, display, etc.)
}

// 3) Capture and crop a specific screen region
if let screen = ScreenshotService.screenUnderMouse() {
    let rect = CGRect(x: 100, y: 100, width: 400, height: 300)
    if let cropped = await screenshots.takeScreenshot(of: screen, croppingTo: rect) {
        // use cropped CGImage
    }
}
```

## Screen Recording

`ScreenRecordService` provides a simple API over ScreenCaptureKit. It presents the system content picker to select a display and then streams frames via callbacks.

### Quick start

```swift
import AppKit
import AVFoundation
import SnapCore

let recorder = ScreenRecordService()

// Optional: observe frames
recorder.onScreenFrame = { sample in
    // Called on a background queue.
    // Convert to CGImage/NSImage if you want to preview.
}

recorder.onAudioFrame = { sample in
    // Called on a background queue for audio frames when enabled.
}

// Start: presents the system content picker for a single display
// If permission is not granted, macOS will prompt on first start.
recorder.startRecording(
    scale: .normal,       // hint for pixel scale (1x/2x)
    showsCursor: true,    // overlay mouse cursor in the video
    capturesAudio: true   // include system/app audio when available
)

// Later, stop and clean up
Task { @MainActor in
    await recorder.stopRecording()
}
```

### Converting frames for preview

Video frames arrive as `.screen` `CMSampleBuffer` objects. To preview them in your UI you can convert the buffer’s image to a `CGImage` using Core Image:

```swift
import CoreImage

let ciContext = CIContext()

recorder.onScreenFrame = { sample in
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
        // Update your NSImageView / CALayer on the main thread
    }
}
```

For recording to a file (e.g., `.mp4`), wire `onScreenFrame` and `onAudioFrame` to an `AVAssetWriter`. SnapCore does not include a muxer by design to keep the core minimal and testable.

Another example converting to `NSImage` on the main actor (using a stored `CIContext` and updating UI state):

```swift
import AppKit
import CoreImage

// e.g., class property
let ciContext = CIContext()

screenRecord.onScreenFrame = { [weak self] sample in
    Task { @MainActor [weak self] in
        guard let self = self,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { return }
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        guard let cg = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        self.currentFrameImage = img
    }
}
```

### API reference

- `ScreenRecordService`
  - `onScreenFrame: ((CMSampleBuffer) -> Void)?`: called for video frames.
  - `onAudioFrame: ((CMSampleBuffer) -> Void)?`: called for audio frames when enabled.
  - `hasScreenRecordPermission() -> Bool`: returns current Screen Recording authorization state.
  - `startRecording(scale: VideoScale = .normal, showsCursor: Bool = true, capturesAudio: Bool = true)`: presents the system picker and begins streaming frames after selection.
  - `stopRecording()`: stops capture and releases resources.

- `VideoScale`
  - `.normal` (1x), `.high` (2x). A hint for the desired scale of the captured content. Depending on system capabilities and future updates, the effective resolution may vary.

> ⚠️ Note: VideoScale is currently not implimented by SnapCore and has no effect.

- `ScreenshotService`
  - `hasScreenshotPermission() -> Bool`: checks Screen Recording permission and may trigger the macOS prompt on first call if not granted.
  - `takeScreenshot() async -> CGImage?`: captures the active display as a `CGImage`.
  - `takeScreenshot(of: NSScreen, croppingTo: CGRect) async -> CGImage?`: captures a specific display and returns a cropped `CGImage` (coordinates in points, auto-mapped to pixels).
  - `static screenUnderMouse() -> NSScreen?`: convenience helper returning the display under the current mouse location.

### Notes & caveats

- Permissions: macOS Screen Recording permission is required. If not granted, `startRecording` will trigger the system prompt on first use. Guide users to System Settings → Privacy & Security → Screen Recording, then relaunch.
- Threads: Frame callbacks are invoked on internal background queues. Hop to the main actor for UI updates.
- Picker: The system content picker is limited to single-display selection in the current build.
- Audio: When `capturesAudio` is `true`, audio sample buffers are delivered. You are responsible for mixing/muxing.
- Cleanup: Always call `stopRecording()` when done to stop the stream and deactivate the picker.
