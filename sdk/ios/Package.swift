// swift-tools-version:5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "NativeRPCKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "NativeRPCKit",
            targets: ["NativeRPCKit"]
        ),
        .executable(
            name: "NativeRPCKitMacros",
            targets: ["NativeRPCKitMacros"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "NativeRPCKitMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/NativeRPCKitMacros"
        ),
        .target(
            name: "NativeRPCKit",
            dependencies: [],
            path: "Sources/NativeRPCKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableExperimentalFeature("SymbolLinkageMarkers"),
            ]
        ),
        .testTarget(
            name: "NativeRPCKitTests",
            dependencies: ["NativeRPCKit"],
            path: "Tests/NativeRPCKitTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
