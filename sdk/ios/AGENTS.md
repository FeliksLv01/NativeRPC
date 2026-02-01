# AGENTS - iOS SDK

This folder contains the **standalone Swift SDK** for NativeRPC.

## Important

This is a **connection-agnostic SDK** with **zero Flutter dependencies**. It can be used in:
- Pure Swift iOS apps
- Swift macOS apps
- Flutter apps (via `native_rpc_flutter` plugin)
- Any project that implements `NativeRPCConnection` protocol

## Protocol

NativeRPC uses a **simplified JSON-RPC 2.0** protocol:

```json
// Incoming Request
{"id": "1", "method": "counter.increment", "params": {"step": 1}}

// Outgoing Response (success)
{"id": "1", "result": 42}

// Outgoing Response (error)
{"id": "1", "error": {"code": -32601, "message": "Method not found"}}

// Outgoing Notification (event)
{"method": "counter.countChanged", "params": {"count": 42}}
```

## What Lives Here

### Sources/NativeRPCKit/
- **Core/**: `NativeRPCHost`, `NativeRPCService`, `NativeRPCMessage`, `NativeRPCError`, `Promise`, `Convertible`
  - Host manages services and connections
  - Services are defined using DSL
  - Message/Error handle protocol communication
  - Promise enables callback-style async functions
  - Convertible provides automatic type conversion from JSON
- **DSL/**: `ServiceDefinitionBuilder`, `ServiceDefinition`, `DSLFactories`
  - Expo Modules-inspired declarative syntax
  - `@ServiceDefinitionBuilder` attribute for service definitions
  - Supports sync functions, async/await, and Promise-style async
- **Connection/**: `NativeRPCConnection` protocol
  - Abstract interface for any transport (MethodChannel, WebSocket, etc.)
  - Implement this protocol to add custom connections

### Tests/
- Swift Package unit tests (21 tests)

## Swift Package Structure

This is a standard Swift Package Manager project:

```swift
// Package.swift
.library(name: "NativeRPCKit", targets: ["NativeRPCKit"])
```

## Usage Examples

### Basic Service Definition

```swift
import NativeRPCKit

class MyService: NativeRPCService {
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("myservice")
        
        // Sync function
        Function("add") { (a: Int, b: Int) -> Int in
            a + b
        }
        
        // Async function with Swift async/await
        AsyncFunction("fetchData") { (id: String) async throws -> [String: Any] in
            try await self.repository.fetch(id)
        }
        
        // Events this service can emit
        Events("dataChanged", "statusUpdated")
    }
}
```

### Async Functions

#### Swift async/await (Preferred)

```swift
// Simple async function
AsyncFunction("fetchUser") { (id: String) async throws -> User in
    try await api.getUser(id)
}

// Run on specific queue
AsyncFunction("processImage") { (data: Data) async throws -> Data in
    // Heavy processing
}.runOnQueue(backgroundQueue)

// Run on main thread (for UI operations)
AsyncFunction("updateUI") { (text: String) async throws -> Void in
    // UI update logic
}.runOnMain()
```

#### Promise-style (for callback-based APIs)

```swift
// Promise with no arguments
AsyncFunction("fetchAll") { (promise: Promise) in
    LegacyAPI.fetchAll { result, error in
        if let error = error {
            promise.reject(error)
        } else {
            promise.resolve(result)
        }
    }
}

// Promise with arguments
AsyncFunction("fetchUser") { (id: String, promise: Promise) in
    UserAPI.fetch(id) { user, error in
        if let error = error {
            promise.reject(error)
        } else {
            promise.resolve(user?.toDictionary())
        }
    }
}

// With timeout
AsyncFunction("slowOperation") { (promise: Promise) in
    // ...
}.withTimeout(30.0)  // 30 second timeout

// Run on main queue
AsyncFunction("uiOperation") { (promise: Promise) in
    // ...
}.runOnMain()
```

### Type Conversion (Convertible)

The SDK automatically converts JSON values to Swift types:

```swift
// Date conversion - accepts ISO8601 strings or timestamps
Function("setDate") { (date: Date) -> Void in
    print(date)  // Automatically converted from "2024-01-15T10:30:00Z" or 1705315800000
}

// URL conversion
Function("openURL") { (url: URL) -> Bool in
    UIApplication.shared.open(url)
}

// CGPoint, CGSize, CGRect
Function("setPosition") { (point: CGPoint) -> Void in
    // Accepts {"x": 10, "y": 20} or [10, 20]
}
```

#### Custom Type Conversion

```swift
struct User {
    let id: String
    let name: String
}

extension User: Convertible {
    static func convert(from value: Any?) throws -> User {
        guard let dict = value as? [String: Any],
              let id = dict["id"] as? String,
              let name = dict["name"] as? String else {
            throw ConversionError.typeMismatch(expected: "User", got: Swift.type(of: value))
        }
        return User(id: id, name: name)
    }
}

// Now you can use User directly as parameter type
Function("updateUser") { (user: User) -> Bool in
    // ...
}
```

#### Built-in Convertibles

| Type | Accepts |
|------|---------|
| `URL` | String (URL or file path) |
| `Date` | ISO8601 string, timestamp (ms) |
| `Data` | Base64 string, byte array |
| `CGPoint` | `{"x": 10, "y": 20}` or `[10, 20]` |
| `CGSize` | `{"width": 100, "height": 200}` or `[100, 200]` |
| `CGRect` | `{"x", "y", "width", "height"}` or `[x, y, w, h]` |
| `UIColor` | `"#RRGGBB"`, `"#RRGGBBAA"`, or `{"r", "g", "b", "a?"}` |

### Standalone Swift App (No Flutter)

```swift
import NativeRPCKit

// 1. Define your service
class MyService: NativeRPCService {
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("myservice")
        Function("hello") { (name: String) -> String in
            return "Hello, \(name)!"
        }
    }
}

// 2. Implement custom connection (e.g., WebSocket)
class MyConnection: NativeRPCConnection {
    func send(_ message: String) {
        // Send JSON over your transport
    }
    // Call onMessage() when receiving data
}

// 3. Setup host
let host = NativeRPCHost()
host.register(MyService())
host.addConnection(MyConnection())
```

### With Flutter (via Plugin)

The `native_rpc_flutter` plugin provides `FlutterMethodChannelConnection`:

```swift
import NativeRPCKit

// In AppDelegate.swift
let host = NativeRPCHost()
host.register(MyService())

let connection = FlutterMethodChannelConnection(channelName: "native_rpc")
host.addConnection(connection)
```

## Build and Test

### Build the SDK

```bash
swift build
```

### Run Tests

```bash
swift test
```

### Use in Flutter Plugin

This SDK is integrated into the Flutter plugin at:
`../../connections/flutter/native_rpc_flutter/ios/`

The plugin's `.podspec` references this SDK.

## Key Classes

### NativeRPCHost
- Central registry for services
- Manages multiple connections
- Routes messages to appropriate services
- Parses incoming JSON-RPC requests
- Sends JSON-RPC responses and notifications

### NativeRPCService
- Base class for all services
- Override `definition()` to define service API
- Call `emit(event, data)` to send events to clients

### NativeRPCConnection (Protocol)
- `func send(_ message: String)` - Send JSON message
- `func onMessage(_ message: String)` - Process incoming message
- Implement this to add custom transports

### NativeRPCMessage
- `NativeRPCMessageParser.parse()` - Parse incoming JSON-RPC messages
- `NativeRPCRequest` - Parsed request with `service` and `methodName` properties
- `NativeRPCResponse` - Success response `{"id", "result"}`
- `NativeRPCErrorResponse` - Error response `{"id", "error"}`
- `NativeRPCNotification` - Event notification `{"method", "params"}`

### NativeRPCError
- `NativeRPCErrorCode` - Standard JSON-RPC 2.0 error codes (-32700 to -32603)
- Custom error codes for service/event not found, timeout, connection error

### ServiceDefinitionBuilder
- DSL for declaratively defining services
- Elements: `Name()`, `Function()`, `AsyncFunction()`, `Events()`
- Fluent API: `.runOnQueue()`, `.runOnMain()`, `.withTimeout()`

### Promise
- Callback-style async for bridging legacy APIs
- Thread-safe with NSLock
- Supports `resolve()`, `reject()`, timeout

### Convertible
- Protocol for automatic type conversion from JSON
- Built-in support for URL, Date, Data, CGPoint, CGSize, CGRect, UIColor
- Extend with custom types

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | parseError | Invalid JSON |
| -32600 | invalidRequest | Invalid request object |
| -32601 | methodNotFound | Method doesn't exist |
| -32602 | invalidParams | Invalid parameters |
| -32603 | internalError | Internal error |
| -32001 | serviceNotFound | Service doesn't exist |
| -32002 | eventNotFound | Event doesn't exist |
| -32003 | eventNotDeclared | Event not in service definition |
| -32004 | timeout | Request timed out |
| -32005 | connectionError | Connection failed |

## Making Changes

1. Edit Swift files in `Sources/NativeRPCKit/`
2. Run tests: `swift test`
3. Test standalone usage in a Swift project
4. Test Flutter integration in `connections/flutter/native_rpc_flutter/example/`
5. Update this AGENTS.md if architecture changes

## Design Philosophy

- **No Flutter Dependencies**: Pure Swift, can run anywhere
- **Protocol-Agnostic**: Connection layer is pluggable
- **Type-Safe**: Swift's type system enforces correctness
- **Declarative**: DSL makes service definition clear and concise
- **JSON-RPC 2.0**: Standard protocol with numeric error codes
- **Expo-Inspired**: Promise API and Convertible similar to Expo Modules

## Related Documentation

- Main README: `../../README.md`
- Protocol Spec: `../../protocol/`
- Flutter Plugin: `../../connections/flutter/native_rpc_flutter/`
