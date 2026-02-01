# AGENTS - Android SDK

This folder contains the **standalone Kotlin SDK** for NativeRPC.

## Important

This is a **connection-agnostic SDK** with **zero Flutter dependencies**. It can be used in:
- Pure Kotlin Android apps
- Kotlin JVM projects
- Flutter apps (via `native_rpc_flutter` plugin)
- Any project that implements `NativeRPCConnection` interface

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

## Protocol Communication

All messages are JSON strings following the simplified JSON-RPC 2.0 protocol:

**Incoming Call**:
```json
{"id": "uuid", "method": "myservice.hello", "params": ["World"]}
```

**Outgoing Result**:
```json
{"id": "uuid", "result": "Hello, World!"}
```

**Outgoing Error**:
```json
{"id": "uuid", "error": {"code": -32601, "message": "Method not found"}}
```

**Outgoing Notification (Event)**:
```json
{"method": "myservice.someEvent", "params": {...}}
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
- **core/**: `NativeRPCHost`, `NativeRPCService`, `NativeRPCMessage`, `NativeRPCError`
  - Host manages services and connections
  - Services are defined using Kotlin DSL
  - Message/Error handle protocol communication
- **dsl/**: `ServiceDefinitionBuilder`, `ServiceDefinition`
  - Kotlin DSL with `serviceDefinition { }` builder
  - Declarative syntax for defining service APIs
- **connection/**: `NativeRPCConnection` interface
  - Abstract interface for any transport (MethodChannel, WebSocket, etc.)
  - Implement this interface to add custom connections

### src/test/kotlin/
- Kotlin unit tests

## Gradle Structure

This is a standard Kotlin library project with Gradle:

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm")
}
```

## Usage Examples

### Standalone Kotlin App (No Flutter)

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.*
import com.itoken.team.nativerpc.connection.*

// 1. Define your service
class MyService : NativeRPCService() {
    override fun definition() = serviceDefinition {
        Name("myservice")
        Function1<String, String>("hello") { name ->
            "Hello, $name!"
        }
    }
}

// 2. Implement custom connection (e.g., WebSocket)
class MyConnection : NativeRPCConnection() {
    override fun send(message: String) {
        // Send JSON over your transport
    }
    // Call onMessage() when receiving data
}

// 3. Setup host
val host = NativeRPCHost()
host.register(MyService())
host.addConnection(MyConnection())
```

### With Flutter (via Plugin)

The `native_rpc_flutter` plugin provides `FlutterMethodChannelConnection`:

```kotlin
import com.itoken.team.nativerpc.core.*

// In MainActivity.kt
val host = NativeRPCHost()
host.register(MyService())

val connection = FlutterMethodChannelConnection(channelName = "native_rpc")
host.addConnection(connection)
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

### Use in Flutter Plugin

This SDK is integrated into the Flutter plugin at:
`../../connections/flutter/native_rpc_flutter/android/`

The plugin's `build.gradle` depends on this SDK.

## Key Classes

### NativeRPCHost
- Central registry for services
- Manages multiple connections
- Routes messages to appropriate services

### NativeRPCService
- Base class for all services
- Override `definition()` to define service API using DSL
- Call `emit(event, data)` to send events to clients

### NativeRPCConnection (Interface)
- `fun send(message: String)` - Send JSON message
- `fun onMessage(message: String)` - Process incoming message
- Implement this to add custom transports

### NativeRPCMessage
- `NativeRPCRequest` - Parsed request with `service` and `methodName` properties
- `NativeRPCResponse` - Success response `{"id", "result"}`
- `NativeRPCErrorResponse` - Error response `{"id", "error"}`
- `NativeRPCNotification` - Event notification `{"method", "params"}`
- `NativeRPCIncomingMessage` - Sealed class for parsed incoming messages

### NativeRPCError
- `NativeRPCErrorCode` - Standard JSON-RPC 2.0 error codes (-32700 to -32603)
- Custom error codes for service/event not found, timeout, connection error

### ServiceDefinitionBuilder (DSL)
- Kotlin DSL for declaratively defining services
- Elements: `Name()`, `Function0/1/2()`, `Events()`, `Constant()`

## Making Changes

1. Edit Kotlin files in `src/main/kotlin/com/itoken/team/nativerpc/`
2. Run tests: `./gradlew test`
3. Test standalone usage in a Kotlin project
4. Test Flutter integration in `connections/flutter/native_rpc_flutter/example/`
5. Update this AGENTS.md if architecture changes

## Design Philosophy

- **No Flutter Dependencies**: Pure Kotlin, can run anywhere (Android, JVM)
- **Protocol-Agnostic**: Connection layer is pluggable
- **Type-Safe**: Kotlin's type system enforces correctness
- **Declarative**: DSL makes service definition clear and idiomatic

## Kotlin DSL Design

The DSL uses function types to define methods with different arities:

```kotlin
Function0<ReturnType>("methodName") { /* no args */ }
Function1<Arg1, ReturnType>("methodName") { arg1 -> /* ... */ }
Function2<Arg1, Arg2, ReturnType>("methodName") { arg1, arg2 -> /* ... */ }
```

This provides type safety while maintaining a clean, declarative syntax.

## Related Documentation

- Main README: `../../README.md`
- Flutter Plugin: `../../connections/flutter/native_rpc_flutter/`
