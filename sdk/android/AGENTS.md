# AGENTS - Android SDK

This folder contains the **standalone Kotlin SDK** for NativeRPC.

## Important

This is a **connection-agnostic SDK** with **zero Flutter dependencies**. It can be used in:
- Pure Kotlin Android apps
- Kotlin JVM projects
- Flutter apps (via `native_rpc_flutter` plugin)
- Any project that implements `NativeRPCConnection` interface

## Architecture (v2.1)

NativeRPC v2.1 uses a **factory-based, per-connection architecture**:

```
┌─────────────────────────────────────────────────────────────┐
│                   NativeRPCServiceCenter                    │
│                   (Global Singleton)                        │
│   Stores: Map<ServiceName, NativeRPCServiceFactory>         │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ getFactory(name)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    NativeRPCConnection                      │
│                    (Per Client/WebView)                     │
│  ┌────────────────┐  ┌─────────────────────────────────────┐│
│  │ NativeRPCContext│  │         NativeRPCStub              ││
│  │ - connectionId  │  │ - Instantiates services lazily     ││
│  │ - connectionType│  │ - Routes calls to service instances ││
│  │ - userInfo      │  │ - Manages service lifecycle        ││
│  └────────────────┘  └─────────────────────────────────────┘│
│                              │                              │
│                  ┌───────────┴───────────┐                  │
│                  ▼                       ▼                  │
│           ┌──────────┐            ┌──────────┐              │
│           │ Service  │            │ Service  │              │
│           │ Instance │            │ Instance │              │
│           └──────────┘            └──────────┘              │
└─────────────────────────────────────────────────────────────┘
```

### Key Concepts

1. **NativeRPCServiceCenter** - Global singleton storing service **factories** (not instances)
2. **NativeRPCConnection** - Base class for connections, auto-creates context + stub
3. **NativeRPCStub** - Per-connection message handler, lazily creates service instances
4. **NativeRPCContext** - Per-connection context with connection info and shared storage
5. **NativeRPCService** - Base class for services, must define a Factory companion object

### Benefits

- **Isolation**: Each connection gets its own service instances
- **State**: Services can maintain per-connection state
- **Cleanup**: Service instances are destroyed when connection closes
- **Scalability**: Supports multiple concurrent connections (WebViews, Flutter engines)

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

## What Lives Here

### src/main/kotlin/com/itoken/team/nativerpc/

- **core/**
  - `NativeRPCServiceCenter.kt` - Global service factory registry
  - `NativeRPCStub.kt` - Per-connection message router
  - `NativeRPCContext.kt` - Per-connection context
  - `NativeRPCService.kt` - Base class for services
  - `NativeRPCMessage.kt` - JSON-RPC message types
  - `NativeRPCError.kt` - Error types and codes
- **dsl/**
  - `ServiceDefinitionBuilder.kt` - Kotlin DSL builder
  - `ServiceDefinition.kt` - Function/event definitions
- **connection/**
  - `NativeRPCConnection.kt` - Base class for connections
  - `FlutterMethodChannelConnection.kt` - Flutter MethodChannel implementation
  - `WebViewConnection.kt` - Android WebView implementation

### src/test/kotlin/
- Kotlin unit tests

## Usage Examples

### 1. Define a Service with Factory (Params Pattern)

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.*

// Define Params data classes for methods with parameters
data class AddParams(val value: Int)
data class SetValueParams(val value: Int)

class CounterService(context: NativeRPCContext? = null) : NativeRPCService() {
    
    // Factory for per-connection instantiation
    companion object {
        val Factory = object : NativeRPCServiceFactory<CounterService> {
            override val serviceName = "counter"
            override fun create(context: NativeRPCContext?) = CounterService(context)
        }
    }
    
    init { this.internalContext = context }
    
    private var count = 0
    
    override fun definition() = serviceDefinition {
        // Note: Name() is no longer needed - serviceName from Factory is used automatically
        
        // No params: Function<ReturnType>("name") { ... }
        Function<Int>("getValue") { count }
        
        Function<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // With params: Function<ParamsType, ReturnType>("name") { params -> ... }
        Function<AddParams, Int>("add") { params ->
            count += params.value
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Function<SetValueParams, Int>("setValue") { params ->
            count = params.value
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}
```

### 2. Register Services at App Startup

```kotlin
import com.itoken.team.nativerpc.core.NativeRPCServiceCenter

// In Application.onCreate() or MainActivity
NativeRPCServiceCenter.register(CounterService.Factory)
NativeRPCServiceCenter.register(UserService.Factory)

// Alternative: Lambda factory
NativeRPCServiceCenter.register("counter") { context ->
    CounterService(context)
}
```

### 3. Create Connections

#### With Flutter (via MethodChannel)

```kotlin
import com.itoken.team.nativerpc.connection.FlutterMethodChannelConnection
import io.flutter.plugin.common.MethodChannel

// In MainActivity.configureFlutterEngine()
val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "native_rpc")
val connection = FlutterMethodChannelConnection(channel, activity)

// Connection auto-starts and is ready to handle calls
// Services are created on-demand when first called
```

#### With WebView

```kotlin
import com.itoken.team.nativerpc.webview.WebViewNativeRPCBridge

// Create bridge for your WebView
val bridge = WebViewNativeRPCBridge(activity)
bridge.attach(webView)

// When done
bridge.detach()
```

### 4. Custom Connection

```kotlin
class MyWebSocketConnection(
    private val socket: WebSocket
) : NativeRPCConnection(
    connectionType = NativeRPCConnectionType.WEB_SOCKET
) {
    override fun send(data: String) {
        socket.send(data)
    }
    
    // Call handleReceivedData() when data arrives
    fun onMessageReceived(message: String) {
        handleReceivedData(message)
    }
}
```

## Build and Test

### Build the SDK

```bash
./gradlew build
```

### Run Tests

```bash
./gradlew test
```

## Key Classes

### NativeRPCServiceCenter
- Global singleton storing service factories
- Thread-safe with read-write lock
- `register(factory)` - Register a service factory
- `register(name) { context -> Service(context) }` - Lambda registration
- `getRegisteredServiceNames()` - List registered services
- `reset()` - Clear all registrations (for testing)

### NativeRPCService
- Base class for all services
- Override `definition()` to define service API using DSL
- Add `Factory` companion object for registration
- Call `emit(event, data)` to send events
- Access `context` for connection-scoped state

### NativeRPCServiceFactory
- Interface for creating service instances
- `serviceName` - Unique service identifier
- `supportedConnectionTypes` - Connection types this service supports
- `create(context)` - Create new instance with context

### NativeRPCConnection
- Base class for all connections
- Auto-creates `NativeRPCContext` and `NativeRPCStub`
- Override `send(data)` to send JSON messages
- Call `handleReceivedData(data)` when data arrives
- Call `close()` to clean up

### NativeRPCStub
- Per-connection message router
- Lazily instantiates services on first call
- Routes calls to appropriate service methods
- Handles event delivery
- Destroys services on connection close

### NativeRPCContext
- Per-connection context
- `connectionId` - Unique connection identifier
- `connectionType` - FLUTTER, WEB_VIEW, WEB_SOCKET, etc.
- `userInfo` - Mutable dictionary for custom data
- `activity` - Optional Android Activity reference

### ServiceDefinitionBuilder (DSL)
- Kotlin DSL for declaratively defining services
- `Name("serviceName")` - Set service name (deprecated, auto-set from Factory.serviceName)
- **New Params Pattern (Recommended):**
  - `Function<R>("name") { }` - No-param sync method
  - `Function<Params, R>("name") { params -> }` - Sync method with Params
  - `AsyncFunction<R>("name") { }` - No-param async method
  - `AsyncFunction<Params, R>("name") { params -> }` - Async method with Params
- **Legacy API (Deprecated):**
  - `Function0/1/2<...>("name") { }` - Define methods (deprecated, use Params pattern)
  - `AsyncFunction0/1/2<...>("name") { }` - Define async methods (deprecated)
- `Events("event1", "event2")` - Declare events
- `Constant("name") { value }` - Define constants

## Migration from v2.0 (NativeRPCHost)

If you're migrating from the old `NativeRPCHost` architecture:

### Before (v2.0)

```kotlin
// ❌ Old pattern - shared service instances
val host = NativeRPCHost()
host.register(CounterService())  // Instance, not factory
host.addConnection(connection)
```

### After (v2.1)

```kotlin
// ✅ New pattern - per-connection service instances with Params pattern
// 1. Define Params data classes
data class AddParams(val value: Int)

// 2. Add Factory to your service class
class CounterService(context: NativeRPCContext? = null) : NativeRPCService() {
    companion object {
        val Factory = object : NativeRPCServiceFactory<CounterService> {
            override val serviceName = "counter"
            override fun create(context: NativeRPCContext?) = CounterService(context)
        }
    }
    
    init { this.internalContext = context }
    
    private var count = 0
    
    override fun definition() = serviceDefinition {
        // No params
        Function<Int>("getValue") { count }
        
        // With Params
        Function<AddParams, Int>("add") { params ->
            count += params.value
            count
        }
        
        Events("countChanged")
    }
}

// 3. Register factory at startup
NativeRPCServiceCenter.register(CounterService.Factory)

// 4. Create connection (no host needed)
val connection = FlutterMethodChannelConnection(channel, activity)
```

## Design Philosophy

- **No Flutter Dependencies**: Pure Kotlin, can run anywhere (Android, JVM)
- **Protocol-Agnostic**: Connection layer is pluggable
- **Per-Connection Isolation**: Each connection gets its own service instances
- **Factory Pattern**: Services are created on-demand with context
- **Type-Safe**: Kotlin's type system enforces correctness
- **Declarative**: DSL makes service definition clear and idiomatic

## Code Generation

Services can be generated from TypeScript interface definitions using the NativeRPC code generator:

```bash
cd codegen
npm run generate -- generate --config examples/config.json --kotlin
```

Generated services include:
- Factory companion object for registration
- `init` block to set context
- `definition()` using `serviceDefinition` DSL
- Type-safe event emitter methods

Example generated structure:

```kotlin
// Params data classes for methods with parameters
data class AddParams(val value: Double)
data class AddTwoParams(val a: Double, val b: Double)

class CounterRPCService(context: NativeRPCContext? = null) : NativeRPCService() {
    companion object {
        val Factory = object : NativeRPCServiceFactory<CounterRPCService> {
            override val serviceName = "counter"
            override fun create(context: NativeRPCContext?) = CounterRPCService(context)
        }
    }

    init { this.internalContext = context }

    override fun definition() = serviceDefinition {
        // No params: Function<ReturnType>
        Function<Double>("getValue") {
            // TODO: Implement getValue
            throw NotImplementedError("Not implemented: getValue")
        }
        
        // With params: Function<ParamsType, ReturnType>
        Function<AddParams, Double>("add") { params ->
            // TODO: Implement add
            // Available: params.value
            throw NotImplementedError("Not implemented: add")
        }
        
        Function<AddTwoParams, Double>("addTwo") { params ->
            // TODO: Implement addTwo
            // Available: params.a, params.b
            throw NotImplementedError("Not implemented: addTwo")
        }
        
        Events("countChanged")
    }
}
```

See `../../codegen/AGENTS.md` for code generator documentation.

## Related Documentation

- Main README: `../../README.md`
- Code Generator: `../../codegen/`
- Flutter Plugin: `../../connections/flutter/native_rpc_flutter/`
- iOS SDK: `../../sdk/ios/`
