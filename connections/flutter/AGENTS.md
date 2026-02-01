# AGENTS - Flutter Connection

This folder contains the Flutter connection implementation for NativeRPC.

## Architecture (v2.1)

The Flutter plugin now uses the **NativeRPC Android/iOS SDK** as a dependency:

```
┌─────────────────────────────────────────────────────────────┐
│                   Flutter App (Dart)                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              native_rpc_flutter plugin                 │ │
│  │  - NativeRPC.call('service.method')                    │ │
│  │  - NativeRPC.on('service.event', callback)             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                    MethodChannel (JSON-RPC)
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Native Platform                        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              NativeRPC SDK (Android/iOS)               │ │
│  │  - NativeRPCServiceCenter (global factory registry)    │ │
│  │  - FlutterMethodChannelConnection (per-engine)         │ │
│  │  - NativeRPCStub (per-connection service router)       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Structure

```
flutter/
└── native_rpc_flutter/           # Flutter plugin package
    ├── lib/
    │   ├── native_rpc_flutter.dart     # Package export
    │   └── src/
    │       ├── native_rpc.dart         # Simple singleton API
    │       ├── runtime/
    │       │   ├── native_rpc_message.dart   # Message models
    │       │   └── native_rpc_connection.dart # Connection interface
    │       └── connection/
    │           └── method_channel_connection.dart  # MethodChannel impl
    │
    ├── ios/Classes/
    │   ├── NativeRpcPlugin.swift               # Plugin registration
    │   └── FlutterMethodChannelConnection.swift # MethodChannel handler
    │
    └── android/
        └── src/main/kotlin/.../
            └── NativeRpcPlugin.kt              # Plugin registration
                                                # (Uses SDK's FlutterMethodChannelConnection)
```

## Key Changes in v2.1

### Android

- **Removed** duplicate core files (NativeRPCService.kt, NativeRPCHost.kt, etc.)
- **Now uses** Android SDK as source dependency
- **NativeRpcPlugin** provides convenience methods that delegate to SDK

### iOS

- **Uses** NativeRPCKit SDK
- **NativeRpcPlugin** provides convenience methods for service registration

## Protocol

Uses simplified JSON-RPC 2.0 format:

```json
// Request (Flutter → Native)
{"id": "uuid", "method": "counter.increment", "params": {"step": 1}}

// Response (Native → Flutter)
{"id": "uuid", "result": 42}
{"id": "uuid", "error": {"code": -32601, "message": "Method not found"}}

// Event/Notification (Native → Flutter, no id)
{"method": "counter.countChanged", "params": {"count": 42}}
```

## Usage

### Dart Side (Flutter)

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

// Initialize (optional, auto-initializes on first use)
NativeRPC.initialize();

// Call methods
final count = await NativeRPC.call<int>('counter.increment');
final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});

// Subscribe to events
void onCountChanged(Map<String, dynamic> data) {
  print('Count: ${data['count']}');
}
NativeRPC.on('counter.countChanged', onCountChanged);

// Unsubscribe
NativeRPC.off('counter.countChanged', onCountChanged);
```

### Native Side (Android - Kotlin)

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.serviceDefinition

// 1. Define service with Factory
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
        // Note: Name is auto-set from Factory.serviceName
        
        Function("getValue") { -> count }
        
        Function("increment") { ->
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}

// 2. Register at startup (in Application.onCreate or MainActivity)
NativeRPCServiceCenter.register(CounterService.Factory)

// 3. Create connection in MainActivity.configureFlutterEngine()
val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "native_rpc")
val connection = FlutterMethodChannelConnection(channel, activity)
```

### Native Side (iOS - Swift)

```swift
import NativeRPCKit

// 1. Define service (NativeRPCService already conforms to NativeRPCServiceRegistrable)
final class CounterService: NativeRPCService {
    override class var serviceName: String { "counter" }
    
    private var count = 0
    
    required init(context: NativeRPCContext?) {
        super.init(context: context)
    }
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // Note: Name is auto-set from serviceName class property
        
        Function("getValue") { () -> Int in
            self.count
        }
        
        Function("increment") { () -> Int in
            self.count += 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Events("countChanged")
    }
}

// 2. Register at startup (e.g., in AppDelegate)
NativeRPCServiceCenter.shared.register(CounterService.self)

// 3. Connection is created automatically by plugin
```

## Code Generation

Services can be generated from TypeScript interface definitions:

```bash
cd codegen
npm run generate -- generate --config examples/config.json
```

See `../../codegen/AGENTS.md` for code generator documentation.

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

## Android SDK Integration

The Android side of the plugin uses the SDK as a source dependency:

```groovy
// settings.gradle
def sdkPath = file("${rootProject.projectDir}/../../../../../../sdk/android")
if (sdkPath.exists()) {
    include ':nativerpc-sdk'
    project(':nativerpc-sdk').projectDir = sdkPath
}

// build.gradle
dependencies {
    implementation project(':nativerpc-sdk')
}
```

## iOS SDK Integration

The iOS side uses NativeRPCKit via CocoaPods:

```ruby
# native_rpc_flutter.podspec
s.dependency 'NativeRPCKit'
```

## Development Commands

```bash
# Install dependencies
flutter pub get

# Analyze code
flutter analyze

# Run tests
flutter test

# Build example
cd example
flutter run
```

## Migration from v2.0

If you previously used `NativeRPCHost`:

### Before (v2.0)

```kotlin
// ❌ Old pattern
val host = NativeRPCHost()
host.register(CounterService())  // Instance
host.addConnection(connection)
```

### After (v2.1)

```kotlin
// ✅ New pattern
// 1. Add Factory to service
// 2. Register factory at startup
NativeRPCServiceCenter.register(CounterService.Factory)
// 3. Create connection (no host needed)
val connection = FlutterMethodChannelConnection(channel, activity)
```

## Related Files

- Android SDK: `../../sdk/android/`
- iOS SDK: `../../sdk/ios/`
- Code Generator: `../../codegen/`
- Example app: `../../examples/flutter_counter/`
- Main README: `../../README.md`
