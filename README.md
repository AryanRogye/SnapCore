# SnapCore

SnapCore is a tiny Swift package for macOS that captures screenshots — a simple, testable core for grabbing `CGImage`s from the screen.

- Build: `swift build`
- Test: `swift test`

Note: Real capture requires macOS Screen Recording permission; tests use mocks to avoid prompts.

## Usage

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
