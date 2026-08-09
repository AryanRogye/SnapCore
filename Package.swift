// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapCore",
    platforms: [
        .macOS("15.2"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SnapCore",
            targets: ["SnapCore"]
        ),
    ],
    dependencies: [],
    // MARK: - Targets
    targets: [
        // MARK: - Core
        .target(
            name: "SnapCore",
            dependencies: [],
            exclude: [
                "Camera/ADDING_RECOGNITION_HANDLERS.md"
            ],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ],
            linkerSettings: [
                // macOS-only frameworks:
                .linkedFramework("ScreenCaptureKit", .when(platforms: [.macOS])),
                .linkedFramework("AppKit",           .when(platforms: [.macOS])),
                
                // iOS-only (if needed):
                .linkedFramework("UIKit",            .when(platforms: [.iOS])),
                
                // both platforms:
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "SnapCoreTests",
            dependencies: ["SnapCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
