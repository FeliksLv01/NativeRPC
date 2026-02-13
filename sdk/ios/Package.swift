// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // The main NativeRPCKit library (includes Scanner, Registrar, SectionItem)
        .library(
            name: "NativeRPCKit",
            targets: ["NativeRPCKit"]
        ),
        // Macros library (optional, for @NativeRPCService macro support)
        .library(
            name: "NativeRPCMacros",
            targets: ["NativeRPCMacros"]
        ),
    ],
    dependencies: [
        // Swift Syntax for macro implementation
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Main target (includes Scanner, AutoRegistrar, SectionItem)
        .target(
            name: "NativeRPCKit",
            dependencies: [],
            path: "Sources/NativeRPCKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Macro implementation (compiler plugin)
        .macro(
            name: "NativeRPCMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "Sources/NativeRPCMacrosPlugin"
        ),
        
        // Macro declaration library (depends on NativeRPCKit for types)
        .target(
            name: "NativeRPCMacros",
            dependencies: [
                "NativeRPCKit",
                "NativeRPCMacrosPlugin",
            ],
            path: "Sources/NativeRPCMacros",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        
        // Test target for NativeRPCKit
        .testTarget(
            name: "NativeRPCKitTests",
            dependencies: ["NativeRPCKit"],
            path: "Tests/NativeRPCKitTests"
        ),
        
        // Test target for NativeRPCMacros (macro expansion tests)
        .testTarget(
            name: "NativeRPCMacrosTests",
            dependencies: [
                "NativeRPCMacros",
                "NativeRPCMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            path: "Tests/NativeRPCMacrosTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
