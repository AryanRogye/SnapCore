// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SnapCore",
    platforms: [
        .macOS(.v14)
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
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "SnapCoreTests",
            dependencies: ["SnapCore"]
        ),
    ]
)
