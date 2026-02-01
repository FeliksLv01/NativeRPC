# AGENTS - iOS SDK

This folder contains the **standalone Swift SDK** for NativeRPC.

## Important

This is a **connection-agnostic SDK** with **zero Flutter dependencies**. It can be used in:
- Pure Swift iOS apps
- Swift macOS apps
- Flutter apps (via `native_rpc_flutter` plugin)
- Any project that extends `NativeRPCConnection` base class

## Architecture (v2.1)

The SDK uses a **per-connection service instance** architecture:

- **`NativeRPCServiceCenter`** - Global singleton storing Service **types** (not instances)
- **`NativeRPCConnection`** - Base class that auto-creates context and stub
- **`NativeRPCStub`** - Per-connection service instance manager (lazy instantiation)
- **`NativeRPCContext`** - Connection-scoped context with shared storage

Services are:
- **Registered by type** at app startup via `NativeRPCServiceCenter`
- **Instantiated per-connection** when first called
- **Destroyed** when the connection closes

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
- **Core/**:
  - `NativeRPCServiceCenter` - Global singleton for service type registration
  - `NativeRPCStub` - Per-connection message handler and service manager
  - `NativeRPCContext` - Connection-scoped context with shared storage
  - `NativeRPCService` - Base class for all services
  - `NativeRPCMessage` - Message types and parser
  - `NativeRPCError` - Error types and codes
  - `Promise` - Callback-style async functions
  - `Convertible` - Automatic type conversion from JSON
- **DSL/**: `ServiceDefinitionBuilder`, `ServiceDefinition`, `DSLFactories`
  - Expo Modules-inspired declarative syntax
  - `@ServiceDefinitionBuilder` attribute for service definitions
  - Supports sync functions, async/await, and Promise-style async
- **Connection/**: `NativeRPCConnection` base class
  - Extend this class to add custom transports
  - Auto-creates context and stub

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
    // Required: provide static service name for registration
    override class var serviceName: String { "myService" }
    
    // Required: init with context
    required init(context: NativeRPCContext?) {
        super.init(context: context)
    }
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // Note: Name() is no longer needed - serviceName is used automatically
        
        // Sync function
        Function("add") { (a: Int, b: Int) -> Int in
            a + b
        }
        
        // Access connection-scoped context
        Function("getUserId") { () -> String? in
            self.context?.get("userId")
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

### Registration and Connection Setup

```swift
import NativeRPCKit

// 1. Register service types at app startup
NativeRPCServiceCenter.shared.register(MyService.self)
NativeRPCServiceCenter.shared.register(CounterService.self)

// 2. Create connection (auto-starts, creates stub and context)
let connection = WebViewNativeRPCConnection(webView: webView)
// or
let connection = FlutterMethodChannelConnection(channel: channel)

// 3. When done:
connection.close()  // destroys all service instances for this connection
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

### Custom Connection Implementation

```swift
import NativeRPCKit

// Extend NativeRPCConnection base class
class MyWebSocketConnection: NativeRPCConnection {
    private let socket: WebSocket
    
    init(socket: WebSocket) {
        self.socket = socket
        super.init(
            connectionType: .webSocket,
            rootView: nil,
            rootViewController: nil
        )
        
        // Set up socket listener
        socket.onMessage = { [weak self] data in
            self?.handleReceivedData(data)
        }
    }
    
    // Override to send JSON string over your transport
    override func send(_ jsonString: String) {
        socket.send(jsonString)
    }
    
    override func close() {
        socket.disconnect()
        super.close()
    }
}

// Usage
let connection = MyWebSocketConnection(socket: socket)
// Connection is ready - services are created per-connection when called
```

### With Flutter (via Plugin)

```swift
import NativeRPCKit
import native_rpc_flutter

// In AppDelegate.swift

// 1. Register service types at app startup
NativeRPCServiceCenter.shared.register(CounterService.self)

// 2. Create connection
if let controller = window?.rootViewController as? FlutterViewController {
    let channel = FlutterMethodChannel(
        name: "native_rpc",
        binaryMessenger: controller.binaryMessenger
    )
    let connection = FlutterMethodChannelConnection(
        channel: channel,
        rootViewController: controller
    )
    // Store connection to keep it alive
    self.rpcConnection = connection
}
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

## Key Classes

### NativeRPCServiceCenter
- Global singleton for service type registration
- Thread-safe with `pthread_rwlock` (fast for read-heavy workloads)
- Services registered by type, not instance

### NativeRPCStub
- Per-connection message handler
- Lazily creates service instances
- Manages event subscriptions
- Destroys services when connection closes

### NativeRPCContext
- Connection-scoped configuration and state
- Thread-safe shared storage (key-value)
- Access to connection type, rootView, rootViewController

### NativeRPCService
- Base class for all services
- Override `definition()` to define service API
- Access `context` for connection-scoped state
- Call `emit(event, data)` to send events

### NativeRPCConnection
- Base class for connections
- Auto-creates context and stub
- Override `send()` for custom transports

### NativeRPCMessage
- `NativeRPCMessageParser.parse()` - Parse incoming JSON-RPC messages
- `NativeRPCRequest` - Parsed request with `service` and `methodName` properties
- `NativeRPCResponse` - Success response `{"id", "result"}`
- `NativeRPCErrorResponse` - Error response `{"id", "error"}`
- `NativeRPCNotification` - Event notification `{"method", "params"}`

### NativeRPCError
- `NativeRPCErrorCode` - Standard JSON-RPC 2.0 error codes (-32700 to -32603)
- Custom error codes for service/event not found, timeout, connection error

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
| -32006 | connectionTypeNotSupported | Service doesn't support connection type |

## Making Changes

1. Edit Swift files in `Sources/NativeRPCKit/`
2. Run tests: `swift test`
3. Test standalone usage in a Swift project
4. Test Flutter integration in `connections/flutter/native_rpc_flutter/example/`
5. Update this AGENTS.md if architecture changes

## Design Philosophy

- **No Flutter Dependencies**: Pure Swift, can run anywhere
- **Per-Connection Isolation**: Each connection has its own service instances
- **Connection-Scoped Context**: Services can share state within a connection
- **Lazy Instantiation**: Services created only when first called
- **Protocol-Agnostic**: Connection layer is pluggable
- **Type-Safe**: Swift's type system enforces correctness
- **Declarative**: DSL makes service definition clear and concise
- **JSON-RPC 2.0**: Standard protocol with numeric error codes
- **High Performance**: Uses `pthread_rwlock` for thread-safe reads

## Code Generation

Services can be generated from TypeScript interface definitions using the NativeRPC code generator:

```bash
cd codegen
npm run generate -- generate --config examples/config.json --swift
```

Generated services include:
- `override class var serviceName` for registration
- `required init(context:)` initializer
- `@ServiceDefinitionBuilder override func definition()` using DSL
- Type-safe event emitter methods

Example generated structure:

```swift
final class CounterRPCService: NativeRPCService {
    override class var serviceName: String { "counter" }
    
    required init(context: NativeRPCContext?) {
        super.init(context: context)
    }

    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // Name is auto-set from serviceName
        Function("getValue") { () -> Double in /* TODO */ }
        Events("countChanged")
    }
}

// Usage: NativeRPCServiceCenter.shared.register(CounterRPCService.self)
```

See `../../codegen/AGENTS.md` for code generator documentation.

## Related Documentation

- Main README: `../../README.md`
- Code Generator: `../../codegen/`
- Protocol Spec: `../../protocol/`
- Flutter Plugin: `../../connections/flutter/native_rpc_flutter/`
