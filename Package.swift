// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SnapCore",
            targets: ["SnapCore"]
        ),
    ],
    targets: [
        .target(
            name: "SnapCore",
            dependencies: [],
            swiftSettings: [
                .define("MACOS_ONLY", .when(platforms: [.macOS]))
            ], linkerSettings: [
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
        ),
    ]
)
