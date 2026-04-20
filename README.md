# SnapCore

SnapCore is a Swift package for Apple platforms with two library products:

- `SnapCore`: screenshot capture and screen-recording primitives for macOS.
- `SnapCoreEngine`: a higher-level recording/playback/export layer built on top of `SnapCore`, with playback/export APIs that also support iOS. This target is still WIP and its API may change.

- Build: `swift build`
- Test: `swift test`

Note: Real capture and recording require macOS Screen Recording permission. Tests use mocks to avoid prompts.

### Requirements

- macOS 15.2+ / iOS 17+
- Swift 5 language mode
- ScreenCaptureKit for macOS capture/recording flows
- Metal support is required only if you use `SnapCoreEngine`'s image-processing path.

The package uses modern Swift concurrency APIs (`async`, actors, `@MainActor`) while building in Swift 5 language mode.

## Products

- `SnapCore`: the stable low-level capture library for macOS screenshot and screen-recording flows.
- `SnapCoreEngine`: the higher-level engine target for recording, playback, export, livestream decoding, and Metal-backed image processing. It is currently WIP and not yet fully documented as a stable public API surface.

## Installation

Swift Package Manager (Git dependency):

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/AryanRogye/SnapCore.git", branch: "main")
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

If you also want the engine target:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SnapCore", package: "SnapCore"),
            .product(name: "SnapCoreEngine", package: "SnapCore")
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

`ScreenRecordService` provides a simple API over ScreenCaptureKit. It presents the system content picker to select a display, caches that selection, and then streams frames through async callbacks.

### Quick start

```swift
import AppKit
import AVFoundation
import CoreImage
import SnapCore

Task { @MainActor in
    let recorder = ScreenRecordService()
    let ciContext = CIContext()

    // Optional: observe frames
    recorder.onScreenFrame = { sample in
        guard sample.shouldAppend,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sample.buffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        _ = ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    recorder.onAudioFrame = { sample in
        guard sample.shouldAppend else { return }
        // Handle sample.buffer when audio capture is enabled.
    }

    // Optional: write directly to a file.
    // Supported extensions in the current implementation: .mov, .mp4, .m4v
    recorder.prepareRecordingOutput(
        url: URL(fileURLWithPath: "/tmp/snapcore-recording.mp4")
    )

    // Start: presents the system content picker for a single display on first use.
    // After a successful selection, later start calls reuse the cached display filter.
    // If permission is not granted, macOS will prompt on first start.
    recorder.startRecording(
        scale: .high,
        showsCursor: true,
        capturesAudio: true,
        fps: .fps120
    )

    // Later, stop and clean up
    await recorder.stopRecording()
}
```

### Converting frames for preview

Video frames arrive as `.screen` `SendableSampleBuffer` values. Use `sample.buffer` to access the wrapped `CMSampleBuffer` and convert the image to a `CGImage` using Core Image:

```swift
import CoreImage

let ciContext = CIContext()

recorder.onScreenFrame = { sample in
    guard sample.shouldAppend,
          let pixelBuffer = CMSampleBufferGetImageBuffer(sample.buffer) else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
        // Update your preview UI
    }
}
```

If you want built-in file output instead of wiring your own `AVAssetWriter`, call `prepareRecordingOutput(url:)` before `startRecording()`. Use `getRecordingOutputErrorMessage()` after a session if ScreenCaptureKit reports a recording-output error.

Another example converting to `NSImage`:

```swift
import AppKit
import CoreImage

// e.g., class property
let ciContext = CIContext()

recorder.onScreenFrame = { [weak self] sample in
    guard let self,
          sample.shouldAppend,
          let pixelBuffer = CMSampleBufferGetImageBuffer(sample.buffer) else { return }

    let ciImage = CIImage(cvImageBuffer: pixelBuffer)
    guard let cg = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    self.currentFrameImage = img
}
```

### API reference

- `ScreenRecordService`
  - `onScreenFrame: ((SendableSampleBuffer) async -> Void)?`: called for video frames.
  - `onAudioFrame: ((SendableSampleBuffer) async -> Void)?`: called for audio frames when enabled.
  - `hasScreenRecordPermission() -> Bool`: returns current Screen Recording authorization state.
  - `startRecording(scale: VideoScale = .normal, showsCursor: Bool = true, capturesAudio: Bool = true, fps: FPS = .fps120)`: presents the system picker and begins streaming frames after selection.
  - `stopRecording() async`: stops capture and releases resources.
  - `getCachedFilter() -> SCContentFilter?`: returns the last display filter selected from the system picker.
  - `getLastScaleFactorUsed() -> CGFloat`: returns the backing scale factor used when computing native resolution.
  - `prepareRecordingOutput(url: URL)`: configures file recording for the next session.
  - `getRecordingOutputErrorMessage() -> String?`: returns the last recording-output error message reported by ScreenCaptureKit, if any.

- `VideoScale`
  - `.normal`: targets a 1080-tall output while preserving display aspect ratio.
  - `.medium`: targets a 1440-tall output while preserving display aspect ratio.
  - `.high`: targets a 2160-tall output while preserving display aspect ratio.
  - `.ultra`: targets a 4320-tall output while preserving display aspect ratio.
  - `.native`: uses the selected display's native pixel dimensions.

- `FPS`
  - `.fps30`: records at 30 FPS.
  - `.fps60`: records at 60 FPS.
  - `.fps120`: records at 120 FPS.

- `SendableSampleBuffer`
  - `buffer: CMSampleBuffer`: the wrapped sample buffer.
  - `shouldAppend: Bool`: returns `false` for blank, suspended, or stopped screen frames.

- `ScreenshotService`
  - `hasScreenshotPermission() -> Bool`: checks Screen Recording permission and may trigger the macOS prompt on first call if not granted.
  - `takeScreenshot() async -> CGImage?`: captures the active display as a `CGImage`.
  - `takeScreenshot(of: NSScreen, croppingTo: CGRect) async -> CGImage?`: captures a specific display and returns a cropped `CGImage` (coordinates in points, auto-mapped to pixels).
  - `static screenUnderMouse() -> NSScreen?`: convenience helper returning the display under the current mouse location.

## Camera Capture

`SnapCore` also includes a camera capture service (`CameraCaptureService`) for live video frames.

### Quick start

```swift
import AVFoundation
import CoreImage
import SnapCore

let camera = CameraCaptureService()
let ciContext = CIContext()

Task {
    // 1) Request/check camera access
    guard await camera.isAuthorized() else {
        print("Camera permission required")
        return
    }

    // 2) Receive BGRA pixel buffers
    await camera.setOnPixelBuffer { pixelBuffer in
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        _ = ciContext.createCGImage(ciImage, from: ciImage.extent)
        // update preview / processing pipeline
    }

    // 3) Start camera (front or back)
    do {
        try await camera.startCamera(
            .builtInWideAngleCamera,
            cameraPosition: .front
        )
    } catch {
        print("Failed to start camera: \(error)")
    }
}

// Later, stop camera
Task {
    await camera.stopCamera()
}
```

### Camera API reference

- `CameraCaptureService`
  - `isAuthorized() async -> Bool`: checks/request camera permission.
  - `setOnPixelBuffer(_:) async`: sets the frame callback.
  - `startCamera(_:cameraPosition:) async throws`: starts capture for a device type and position.
  - `stopCamera() async`: stops capture and tears down session I/O.
  - `focus(at:in:) async`: focuses/exposes around a point in view coordinates.
  - `getSession() async -> AVCaptureSession?`: returns the current capture session.

- `CameraPosition`
  - `.front`
  - `.back`

## SnapCoreEngine

`SnapCoreEngine` is the higher-level package target that currently contains:

- recording coordination
- playback coordination
- export helpers
- Metal-backed image processing (lanczos upscaling, exposure, contrast, blur, sharpening, cursor compositing)

The target now bundles its Metal shader files internally. Apps using `SnapCoreEngine` do not need to add `.metal` files to their app target or configure a separate Metal resource bundle.

Current status: the engine target builds successfully, but the API is still WIP and may change.

The examples below mirror the current `TestingSR` app integration. `PreviewView` and `EditorView` are app-owned SwiftUI views layered on top of `SnapCoreEngine`.

### Engine recording example

```swift
import SwiftUI
import SnapCore
import SnapCoreEngine

struct ContentView: View {
    @State private var recorder: Recorder = .init()
    @State private var startProcessing = false
    @State private var editorVM: EditingViewModel?

    var body: some View {
        VStack {
            if let editorVM, startProcessing, !recorder.isStopping {
                EditorView(vm: editorVM) {
                    withAnimation(.snappy) {
                        startProcessing = false
                    }
                }
            } else {
                PreviewView(recorder: recorder) {
                    Task {
                        await processVideo()
                    }
                }

                Button(recorder.isRecording ? "Stop" : "Record") {
                    Task {
                        try await recorder.toggle()
                    }
                }

                Picker("Quality", selection: $recorder.coordinator.scale) {
                    Text("1080p").tag(VideoScale.normal)
                    Text("1440p").tag(VideoScale.medium)
                    Text("4K").tag(VideoScale.high)
                    Text("8K").tag(VideoScale.ultra)
                    Text("Native").tag(VideoScale.native)
                }

                Picker("FPS", selection: $recorder.coordinator.fps) {
                    ForEach(FPS.allCases, id: \.self) { fps in
                        Text(fps.rawValue).tag(fps)
                    }
                }

                Toggle("Custom Cursor", isOn: $recorder.coordinator.recordingInfo.isUsingCustomCursor)
            }
        }
    }

    private func processVideo() async {
        editorVM = await EditingViewModel(recordingInfo: recorder.recordingInfo)
        withAnimation(.snappy) {
            startProcessing = true
        }
    }
}
```

`Recorder` is the main high-level entry point for capture in `SnapCoreEngine`. It owns a `RecordingCoordinator` and exposes a shared `RecordingInfo` instance that feeds playback and export.

### Engine playback example

```swift
import AVFoundation
import SwiftUI
import SnapCoreEngine

@Observable
@MainActor
final class EditingViewModel {
    var recordingInfo: RecordingInfo
    var playbackEngine: PlaybackEngine
    var isPlaying = false

    var totalDuration: Float64 { playbackEngine.totalDuration }
    var currentMouse: CurrentMouseInfo? { playbackEngine.currentMouse }
    var currentCursorMotionState: CursorMotionState? { playbackEngine.currentCursorMotionState }
    var currentTime: Float64 { playbackEngine.currentTime }
    var progress: Double { playbackEngine.progress }

    init(recordingInfo: RecordingInfo) async {
        self.recordingInfo = recordingInfo
        self.playbackEngine = await PlaybackEngine(recordingInfo: recordingInfo)
    }

    func play() {
        isPlaying = true
        playbackEngine.play()
    }

    func pause() {
        isPlaying = false
        playbackEngine.pause()
    }

    func seek(to progress: Double) {
        guard totalDuration > 0 else { return }
        let time = CMTime(seconds: progress * totalDuration, preferredTimescale: 600)
        playbackEngine.seek(to: time)
    }
}
```

### Engine iOS timeline playback example

The current iOS editor flow mirrors the `VideoEditor_iOS` app: create a `PlaybackEngine(url:)`, build timeline clip arrays, and call `replaceAllFiles(video:audio:)` on the main actor.

```swift
import AVFoundation
import Observation
import SnapCoreEngine

struct TimelineVideoClip {
    let url: URL
    let trimIn: Double
    let trimOut: Double
    let sourceDuration: Double
    let timelineStart: Double
    let orientation: Int
    let volume: CGFloat
}

struct TimelineAudioClip {
    let url: URL
    let trimIn: Double
    let trimOut: Double
    let sourceDuration: Double
    let timelineStart: Double
    let orientation: Int
    let volume: CGFloat
}

@Observable
@MainActor
final class EditingViewModel {
    var mediaURL: URL
    var playbackEngine: PlaybackEngine

    init(url: URL) {
        self.mediaURL = url
        self.playbackEngine = PlaybackEngine()
        self.playbackEngine.load(url: url)
    }

    func reloadTimeline(
        videoClips: [TimelineVideoClip],
        audioClips: [TimelineAudioClip]
    ) async throws {
        let videoFiles = videoClips.map {
            VideoFileInfo(
                url: $0.url,
                start: $0.trimIn / $0.sourceDuration,
                end: $0.trimOut / $0.sourceDuration,
                timelineStart: $0.timelineStart,
                orientation: $0.orientation,
                volume: $0.volume
            )
        }

        let audioFiles = audioClips.map {
            AudioFileInfo(
                url: $0.url,
                start: $0.trimIn / $0.sourceDuration,
                end: $0.trimOut / $0.sourceDuration,
                timelineStart: $0.timelineStart,
                orientation: $0.orientation,
                volume: $0.volume
            )
        }

        try await playbackEngine.playerCoordinator.replaceAllFiles(
            video: videoFiles,
            audio: audioFiles
        )
    }

    func play() {
        playbackEngine.play()
    }

    func pause() {
        playbackEngine.pause()
    }

    func seek(to progress: Double) {
        guard playbackEngine.totalDuration > 0 else { return }
        let time = CMTime(seconds: progress * playbackEngine.totalDuration, preferredTimescale: 600)
        playbackEngine.seek(to: time)
    }
}
```

Current timeline behavior in `replaceAllFiles(video:audio:)`:

- Video is resolved to a single visible lane; overlapping video clips do not layer.
- A later video clip trims the visible tail of an earlier overlapping video clip.
- Embedded audio from video clips is preserved for the resolved visible video ranges.
- Separate audio clips are inserted on as many composition audio tracks as needed, so they can overlap and mix.

### Engine cursor customization example

`PlaybackImageCoordinator` exposes live cursor styling models. The `TestingSR` app binds sliders directly to both `cursorConfig` and `cursorShadowConfig`, so changes are reflected in playback without rebuilding the engine:

```swift
import SwiftUI
import SnapCoreEngine

struct CursorControls: View {
    @Bindable var vm: EditingViewModel

    var body: some View {
        VStack {
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.scale, in: 1.0...8.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.lineWidth, in: 1.0...8.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.roundness, in: 1.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.distanceFromBottomScale, in: 0.1...0.6)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.distanceFromCenterScale, in: 0.01...0.25)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.distanceFromHorizontal, in: 0.05...0.4)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorConfig.wingDistanceDown, in: 0.0...0.2)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowX, in: 0.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowY, in: 0.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowOpacity, in: 0.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowSharpX, in: 0.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowSharpY, in: 0.0...10.0)
            Slider(value: $vm.playbackEngine.imageCoordinator.cursorShadowConfig.cursorShadowSharpOpacity, in: 0.0...10.0)
        }
    }
}
```

For playback UI overlays, `PlaybackEngine.currentCursorMotionState` exposes the current cursor delta and angle state alongside `currentMouse`.

### Engine export example

```swift
import SwiftUI
import SnapCoreEngine

@Observable
@MainActor
final class ExportViewModel {
    var editingVM: EditingViewModel
    let exporter = Exporter()

    init(editingVM: EditingViewModel) {
        self.editingVM = editingVM
    }

    @discardableResult
    func export(start: Float64, end: Float64) async throws -> URL? {
        try await exporter.export(
            recordingInfo: editingVM.recordingInfo,
            start: start,
            end: end,
            sharpness: Float(editingVM.playbackEngine.imageCoordinator.sharpness),
            contrast: Float(editingVM.playbackEngine.imageCoordinator.contrast)
        )
    }
}

struct ExportButton: View {
    @Bindable var editingVM: EditingViewModel
    @State private var exportVM: ExportViewModel

    init(editingVM: EditingViewModel) {
        self.editingVM = editingVM
        self.exportVM = ExportViewModel(editingVM: editingVM)
    }

    var body: some View {
        Button("Export") {
            Task {
                _ = try? await exportVM.export(
                    start: editingVM.playbackEngine.start,
                    end: editingVM.playbackEngine.end
                )
            }
        }
    }
}
```

### Engine livestream decoding example

`SnapCoreEngine` does not ship peer discovery or transport, but it does support streaming encoded video into any `OutputStream` and decoding it back from any `InputStream`. The `Phmirror` app uses `MultipeerConnectivity` to provide those streams.

macOS host side:

```swift
import Foundation
import SnapCoreEngine

@MainActor
func startLivestream(recorder: Recorder, stream: OutputStream) async throws {
    try await recorder.toggle(with: .livestream(stream))
}
```

iOS client side:

```swift
import Foundation
import UIKit
import SnapCoreEngine

final class StreamViewModel {
    let decoder = LiveFileWritingDecoder()
    var latestFrame: UIImage?
    var status = "Idle"

    init() {
        decoder.onFrameImage = { [weak self] image, _ in
            self?.latestFrame = UIImage(cgImage: image)
        }

        decoder.onStatus = { [weak self] status in
            self?.status = status
        }
    }

    func attach(stream: InputStream) {
        decoder.start(stream: stream)
    }

    func stop() {
        decoder.stop()
    }
}
```

The stream transport layer is app-owned. `Phmirror` uses `MultipeerConnectivity`, but any source that gives you an `OutputStream`/`InputStream` pair works. On macOS, the decoder API is the same, but you would usually convert the `CGImage` into an `NSImage` instead of a `UIImage`.

### Notes & caveats

- Permissions: macOS Screen Recording permission is required. If not granted, `startRecording` will trigger the system prompt on first use. Guide users to System Settings → Privacy & Security → Screen Recording, then relaunch.
- Availability: SnapCore now targets macOS 15.2+ and iOS 17+.
- Actors: `ScreenRecordService` is `@MainActor`, and frame handlers are async callbacks awaited by the service. Keep handlers lightweight and offload heavy work if needed.
- Picker: The system content picker is limited to single-display selection in the current build. After a successful selection, the chosen filter is cached and reused for later `startRecording()` calls on the same service instance.
- Audio: When `capturesAudio` is `true`, audio sample buffers are delivered. You are responsible for mixing/muxing.
- Frame rate: pass `fps` to `startRecording()` to choose `30`, `60`, or `120` FPS. The default is `.fps120`.
- File output: call `prepareRecordingOutput(url:)` before `startRecording()` if you want ScreenCaptureKit to write a `.mov`, `.mp4`, or `.m4v` file directly.
- iOS playback: you can initialize with `PlaybackEngine(url:)` or use `PlaybackEngine()` then `load(url:)`.
- iOS scrubbing: use `previewSeek(to:)` for lightweight timeline preview seeks, and `seek(to:)` for committed seeks.
- Timeline playback: `replaceAllFiles(video:audio:)` is `@MainActor`; video stays single-lane while audio clips can layer.
- Livestreaming: `RecordingConfig.livestream(OutputStream)` writes encoded frames to an app-provided stream, and `LiveFileWritingDecoder` reconstructs frames from an `InputStream`.
- Metal: `SnapCoreEngine` compiles its bundled shader sources internally from package resources. Consumer apps do not need extra Metal-specific setup beyond running on a Metal-capable Mac.
- Recording models: `RecordingInfo` stores the captured file URL, preview image, frame metadata, display metadata, and whether a custom cursor should be rendered during playback/export.
- Cursor rendering: `CursorConfig` is public and can be stored with SwiftData, which is how `TestingSR` saves and reloads cursor presets.
- Cursor shadows: `PlaybackImageCoordinator.cursorShadowConfig` controls the rendered cursor shadow offsets and opacities used during playback/export compositing.
- Cursor motion: `PlaybackEngine.currentCursorMotionState` exposes cursor movement deltas for editor UI or future motion-driven cursor effects.
- Cleanup: Always call `stopRecording()` when done to stop the stream, clear any pending recording output URL, and deactivate the picker.
