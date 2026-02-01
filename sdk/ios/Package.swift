// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NativeRPCKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // The main NativeRPCKit library
        .library(
            name: "NativeRPCKit",
            targets: ["NativeRPCKit"]
        ),
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        // Main target
        .target(
            name: "NativeRPCKit",
            dependencies: [],
            path: "Sources/NativeRPCKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        // Test target
        .testTarget(
            name: "NativeRPCKitTests",
            dependencies: ["NativeRPCKit"],
            path: "Tests/NativeRPCKitTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
