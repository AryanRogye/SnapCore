// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapCore",
    platforms: [
        .macOS("15.2")
    ],
    products: [
        .library(
            name: "SnapCore",
            targets: ["SnapCore"]
        ),
        .library(
            name: "SnapCoreEngine",
            targets: ["SnapCoreEngine"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.4.0")
        ),
    ],
    // MARK: - Targets
    targets: [
        // MARK: - Core
        .target(
            name: "SnapCore",
            dependencies: [],
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
        .target(
            name: "SnapCoreEngine",
            dependencies: [
                "SnapCore",
                .product(name: "Collections", package: "swift-collections")
            ],
            resources: [
                .copy("Playback/Image/Contrast/Contrast.metal"),
                .copy("Playback/Image/Sharpen/sharpen.metal")
            ]
        ),
        .testTarget(
            name: "SnapCoreTests",
            dependencies: ["SnapCore"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
