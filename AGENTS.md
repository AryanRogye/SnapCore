# Repository Guidelines

## Project Structure & Module Organization
- Swift Package (SwiftPM) targeting macOS 14; library product `SnapCore` defined in `Package.swift`.
- Source: `Sources/SnapCore/` organized by feature folders: `Models/`, `Protocols/`, `Services/` (e.g., `ScreenshotService.swift`, `ScreenshotProviding.swift`).
- Tests: `Tests/SnapCoreTests/` (e.g., `ScreenshotProviderTests.swift`, `MockScreenshotProvider.swift`). Keep test files near their subject and mirror folder names.

## Build, Test, and Development Commands
- `swift build`: Compile in debug.
- `swift build -c release`: Optimized build.
- `swift test`: Run the XCTest suite.
- `swift test --filter SnapCoreTests`: Run a subset by test target or name.

## Coding Style & Naming Conventions
- Language: Swift 6; 4‑space indentation; braces on same line; trailing commas allowed.
- Types/protocols: UpperCamelCase (e.g., `ScreenshotService`, `ScreenshotProviding`); members: lowerCamelCase.
- One primary type per file; keep folders `Models/`, `Protocols/`, `Services/` consistent.
- Public API in the `SnapCore` module must be marked `public` and documented succinctly.
- Use Xcode/SwiftPM default formatting; no repo‑pinned linter—avoid introducing new style tools without consensus.

## Testing Guidelines
- Framework: XCTest. Place tests under `Tests/SnapCoreTests/` with filenames ending in `Tests.swift`.
- Name tests `test...` and focus on behavior. Prefer mocks over live ScreenCaptureKit for determinism (see `MockScreenshotProvider`).
- Aim to cover core paths in `ScreenshotService` (capture, cropping, edge cases). Run locally with `swift test`.

## Commit & Pull Request Guidelines
- History favors short, imperative messages (e.g., "fix sync", "make initializer public"). Keep messages concise and scoped.
- Reference issues when relevant (e.g., `Fixes #123`). Squash noisy WIP commits before merge.
- PRs should include: purpose, high‑level changes, testing notes (what you verified with `swift test`), and any permission/UI caveats.

## Security & Configuration Tips
- Real capture requires macOS Screen Recording permission; tests should avoid prompting by using mocks.
- Do not commit secrets or machine‑specific entitlements. Prefer configuration via SwiftPM or environment variables when needed.

## Architecture Overview
- `ScreenshotService` conforms to `ScreenshotProviding` and uses `ScreenCaptureKit` to produce `CGImage`s.
- Models like `ScreenshotScaleMode` express scaling/cropping behavior. Favor protocol‑first design to keep APIs testable and mockable.

