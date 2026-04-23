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
                .copy("Processing/Contrast/Contrast.metal"),
                .copy("Processing/Sharpen/Sharpen.metal"),
                .copy("Processing/Cursor/Cursor.metal"),
                .copy("Processing/Lanczos/Lanczos.metal"),
                .copy("Processing/Exposure/Exposure.metal"),
                .copy("Processing/Blur/Blur.metal"),
                .copy("Processing/Saturation/Saturation.metal"),
                .copy("Processing/Illumination/Illuminance.metal"),
                .copy("Processing/Blending/Blending.metal"),
                .copy("Processing/KernelNxN.metalh")
            ]
        ),
        .testTarget(
            name: "SnapCoreTests",
            dependencies: ["SnapCore"]
        ),
        .testTarget(
            name: "SnapCoreEngineTests",
            dependencies: ["SnapCoreEngine", "SnapCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
