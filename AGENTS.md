# AGENTS

This repository contains NativeRPC - a **protocol-first, SDK-isolated** RPC framework.

## Important Environment Note

**User Environment**: China region  
Always use: `export PUB_HOSTED_URL="https://pub.flutter-io.cn"` before Flutter commands.

## Architecture Overview

NativeRPC is a **protocol**, not just a Flutter plugin. The project is structured to:
1. Define a language-agnostic JSON protocol (simplified JSON-RPC 2.0)
2. Provide standalone iOS and Android SDKs (no Flutter dependencies)
3. Support pluggable connection layers (MethodChannel, WebSocket, custom)
4. Offer a Flutter integration as one use case

## Project Structure

```
NativeRPC/
├── sdk/                             # Standalone native SDKs
│   ├── ios/                        # Swift SDK (NativeRPCKit)
│   │   ├── Sources/NativeRPCKit/   # Source files
│   │   ├── Package.swift           # SPM package
│   │   └── NativeRPCKit.podspec    # CocoaPods spec
│   └── android/                    # Kotlin SDK
│
├── connections/                     # Connection layer implementations
│   └── flutter/
│       └── native_rpc_flutter/     # Flutter plugin (MethodChannel transport)
│
├── codegen/                         # TypeScript code generator
│   ├── src/                        # Generator source code
│   ├── templates/                  # Mustache templates
│   └── examples/                   # Example configs and services
│
├── examples/
│   └── flutter_counter/            # Example Flutter app
│
├── docs/                            # Documentation
│
├── Package.swift                    # Root SPM package (points to sdk/ios)
├── NativeRPCKit.podspec            # Root CocoaPods spec (points to sdk/ios)
└── README.md                        # Main documentation
```

## Key Areas

### Native SDKs (Standalone)

- **iOS SDK**: `sdk/ios/` - Pure Swift, no Flutter dependencies
  - Core: `NativeRPCHost`, `NativeRPCService`, `NativeRPCMessage`, `NativeRPCError`
  - DSL: `ServiceDefinitionBuilder` with Expo Modules-style syntax
  - Connection: `NativeRPCConnection` protocol

- **Android SDK**: `sdk/android/` - Pure Kotlin, no Flutter dependencies
  - Core: Same concepts as iOS
  - DSL: Kotlin DSL with `serviceDefinition { }` builder

### Connection Layer

- **Flutter Plugin**: `connections/flutter/native_rpc_flutter/`
  - Package: `native_rpc_flutter`
  - MethodChannel transport implementation
  - iOS/Android plugin glue code

### Code Generator

- **Location**: `codegen/`
- **Purpose**: Generate type-safe Dart/Swift/Kotlin clients from TypeScript interfaces
- **Config**: `codegen/examples/config.json`
- **Key options**:
  - `rendering.serviceSuffix`: Service class name suffix (default: `"RPCService"`)
  - `rendering.kotlin.packageName`: Kotlin package name (default: `"com.itoken.team"`)

## Common Workflows

### Working with Code Generator

```bash
cd codegen
npm install
npm run build
npm run generate -- generate --config examples/config.json
```

### Working with Flutter Plugin

```bash
cd connections/flutter/native_rpc_flutter
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
flutter pub get
flutter analyze
cd example
flutter run
```

### Working with iOS SDK (Standalone)

```bash
cd sdk/ios
swift build
swift test
```

### Working with Android SDK (Standalone)

```bash
cd sdk/android
./gradlew build
./gradlew test
```

### Running Example App

```bash
cd examples/flutter_counter
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
flutter pub get
flutter run
```

## Design Principles

1. **Protocol-First**: The core is a JSON message protocol, independent of any platform
2. **SDK Isolation**: iOS and Android SDKs have zero Flutter dependencies
3. **Pluggable Connections**: Connection layer is abstracted (MethodChannel, WebSocket, etc.)
4. **Single Channel**: All RPC calls share one connection/channel per host
5. **Type Safety**: Generator produces type-safe code from TypeScript interfaces

## Installation Methods

### iOS

**Swift Package Manager** (root `Package.swift`):
```swift
dependencies: [
    .package(url: "https://github.com/FeliksLv01/NativeRPC.git", from: "1.0.0")
]
```

**CocoaPods** (root `NativeRPCKit.podspec`):
```ruby
pod 'NativeRPCKit', :git => 'https://github.com/FeliksLv01/NativeRPC.git'
```

### Flutter

```yaml
dependencies:
  native_rpc_flutter:
    git:
      url: https://github.com/FeliksLv01/NativeRPC.git
      path: connections/flutter/native_rpc_flutter
```

## Making Changes

### When Modifying Native SDKs
1. Make changes in `sdk/ios/` or `sdk/android/`
2. Test standalone usage (without Flutter)
3. Test Flutter integration in `connections/flutter/native_rpc_flutter/example/`
4. Update AGENTS.md in SDK directory

### When Modifying Flutter Plugin
1. Make changes in `connections/flutter/native_rpc_flutter/`
2. Test with example: `cd example && flutter run`
3. Ensure iOS/Android plugin glue code is updated

### When Modifying Generator
1. Make changes in `codegen/`
2. Run: `npm run build && npm run generate -- generate --config examples/config.json`
3. Verify generated code is correct
4. Update AGENTS.md in codegen directory

## File Paths Reference

All file operations **MUST use absolute paths** because the IDE working directory may differ.

### Important Files
- Main README: `README.md`
- This file: `AGENTS.md`
- iOS SDK: `sdk/ios/`
- Android SDK: `sdk/android/`
- Flutter Plugin: `connections/flutter/native_rpc_flutter/`
- Code Generator: `codegen/`
- Example: `examples/flutter_counter/`
