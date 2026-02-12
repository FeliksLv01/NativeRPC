# NativeRPC

NativeRPC is a **protocol-first RPC framework** with standalone native SDKs for iOS and Android, and pluggable connection layers. It features a declarative, Expo Modules-style DSL for Swift and Kotlin, and ships with a Flutter integration that uses MethodChannel for transport.

## Key Features

- **Protocol-First Design**: NativeRPC is a unified protocol, not just a Flutter plugin
- **Standalone SDKs**: iOS and Android SDKs work independently, no Flutter required
- **Pluggable Connections**: Use MethodChannel, WebSocket, HTTP, or implement custom transports
- **Declarative DSL**: Expo Modules-inspired API for Swift and Kotlin services
- **Type-Safe Code Generation**: Generate Dart/Swift/Kotlin clients from TypeScript interfaces
- **Single Channel Design**: All RPC calls share one connection per host
- **Interceptor Middleware**: Pluggable middleware for logging, monitoring, and custom processing

## Installation

### iOS (Swift Package Manager)

Add the following to your `Package.swift` or use Xcode's "Add Package Dependencies":

```swift
dependencies: [
    .package(url: "https://github.com/FeliksLv01/NativeRPC.git", from: "1.0.0")
]
```

Or add via Xcode: File → Add Package Dependencies → Enter repository URL.

### iOS (CocoaPods)

Add to your `Podfile`:

```ruby
pod 'NativeRPCKit', :git => 'https://github.com/FeliksLv01/NativeRPC.git'
```

### Android (Gradle)

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.itoken.team:nativerpc:1.0.0")
}
```

### Flutter

Add to your `pubspec.yaml`:

```yaml
dependencies:
  native_rpc_flutter:
    git:
      url: https://github.com/FeliksLv01/NativeRPC.git
      path: connections/flutter/native_rpc_flutter
```

## Protocol

NativeRPC uses a **simplified JSON-RPC 2.0** protocol (without the `jsonrpc` field).

### Request (Method Call)

```json
{
  "id": "1",
  "method": "counter.increment",
  "params": {"step": 1}
}
```

### Response (Success)

```json
{
  "id": "1",
  "result": 42
}
```

### Response (Error)

```json
{
  "id": "1",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": {}
  }
}
```

### Notification (Event, no id)

```json
{
  "method": "counter.countChanged",
  "params": {"count": 42}
}
```

## Usage Examples

### Flutter with MethodChannel

**Dart (Flutter app):**

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

// Call methods (auto-initializes on first use)
final value = await NativeRPC.call<int>('counter.increment');
print('New count: $value');

// With parameters
final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});

// Listen to events
NativeRPC.on('counter.countChanged', (data) {
  print('Count changed: ${data["count"]}');
});

// Remove listener
NativeRPC.off('counter.countChanged', myHandler);
```

**Swift (iOS):**

```swift
import NativeRPCKit

class CounterService: NativeRPCService {
    private var count = 0

    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("counter")
        
        Function("increment") { [weak self] () -> Int in
            guard let self else { return 0 }
            self.count += 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Events("countChanged")
    }
}

// In AppDelegate.swift
let host = NativeRPCHost()
host.register(CounterService())

let connection = FlutterMethodChannelConnection(channelName: "native_rpc")
host.addConnection(connection)
```

**Kotlin (Android):**

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.*

class CounterService : NativeRPCService() {
    private var count = 0

    override fun definition() = serviceDefinition {
        Name("counter")
        
        Function0<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}

// In MainActivity.kt
val host = NativeRPCHost()
host.register(CounterService())

val connection = FlutterMethodChannelConnection(channelName = "native_rpc")
host.addConnection(connection)
```

### Standalone iOS SDK (No Flutter)

```swift
import NativeRPCKit

// Create your custom connection (e.g., WebSocket)
class MyWebSocketConnection: NativeRPCConnection {
    func send(_ message: String) {
        // Send JSON message over WebSocket
    }
    
    // Call onMessage() when receiving data
}

let host = NativeRPCHost()
host.register(CounterService())

let connection = MyWebSocketConnection()
host.addConnection(connection)
```

### Standalone Android SDK (No Flutter)

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.connection.*

// Create your custom connection
class MyWebSocketConnection : NativeRPCConnection() {
    override fun send(message: String) {
        // Send JSON message over WebSocket
    }
    
    // Call onMessage() when receiving data
}

val host = NativeRPCHost()
host.register(CounterService())

val connection = MyWebSocketConnection()
host.addConnection(connection)
```

## Logging & Interceptors (iOS)

NativeRPC provides a middleware system for logging, monitoring, and custom processing. By default, the SDK produces no log output.

### Enable Logging

```swift
import NativeRPCKit

// Use built-in logging interceptor
NativeRPCServiceCenter.shared.addInterceptor(
    NativeRPCLoggingInterceptor(logLevel: .info)
)
```

### Custom OSLog Integration

```swift
import NativeRPCKit
import os.log

final class OSLogInterceptor: NativeRPCInterceptor {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.app.NativeRPC",
        category: "NativeRPC"
    )
    
    func willProcessRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        logger.info("→ \(request.method)")
    }
    
    func didProcessRequest(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        let durationMs = String(format: "%.2f", response.duration * 1000)
        if response.isSuccess {
            logger.info("← \(request.method) ✓ (\(durationMs)ms)")
        } else if let error = response.error {
            logger.error("← \(request.method) ✗ [\(error.code)] \(error.message)")
        }
    }
    
    func willSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {
        logger.info("⇢ \(event.event)")
    }
}

// Add to service center
NativeRPCServiceCenter.shared.addInterceptor(OSLogInterceptor())
```

## Code Generation

Generate type-safe clients from TypeScript interfaces:

```bash
cd codegen
npm install
npm run generate -- generate --config examples/config.json
```

See [codegen/README.md](codegen/README.md) for details.

## Error Codes (JSON-RPC 2.0 Standard)

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid request object |
| -32601 | Method not found | Method doesn't exist |
| -32602 | Invalid params | Invalid parameters |
| -32603 | Internal error | Internal error |
| -32001 | Service not found | Service doesn't exist |
| -32002 | Event not found | Event doesn't exist |
| -32003 | Timeout | Request timed out |
| -32004 | Connection error | Connection failed |

## Project Structure

```
NativeRPC/
├── sdk/                             # Standalone native SDKs
│   ├── ios/                        # Swift SDK (NativeRPCKit)
│   └── android/                    # Kotlin SDK
│
├── connections/                     # Connection layer implementations
│   └── flutter/
│       └── native_rpc_flutter/     # Flutter plugin
│
├── codegen/                         # TypeScript code generator
│   ├── src/                        # Generator source
│   ├── templates/                  # Mustache templates
│   └── examples/                   # Example configs
│
├── examples/
│   └── flutter_counter/            # Flutter example app
│
├── docs/                            # Documentation
├── Package.swift                    # SPM package (root)
└── NativeRPCKit.podspec            # CocoaPods spec (root)
```

## Design Principles

1. **Protocol-First**: The message format is language-agnostic JSON (simplified JSON-RPC 2.0)
2. **SDK Isolation**: iOS and Android SDKs have zero Flutter dependencies
3. **Pluggable Connections**: Connection layer is abstracted (MethodChannel, WebSocket, etc.)
4. **Single Channel**: All RPC calls share one connection/channel per host
5. **Type Safety**: Generator produces type-safe code from TypeScript interfaces
6. **Declarative DSL**: Services defined with simple, readable syntax

## License

MIT
