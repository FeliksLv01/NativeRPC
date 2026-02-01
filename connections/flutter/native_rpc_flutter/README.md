# native_rpc_flutter

Flutter plugin for NativeRPC. This package provides:
- Simple singleton API (`NativeRPC.call`, `NativeRPC.on`, `NativeRPC.stream`)
- MethodChannel transport

## Protocol

NativeRPC uses a **simplified JSON-RPC 2.0** protocol:

```json
// Request
{"id": "1", "method": "counter.increment", "params": {"step": 1}}

// Response
{"id": "1", "result": 42}

// Error
{"id": "1", "error": {"code": -32601, "message": "Method not found"}}

// Notification (Event)
{"method": "counter.countChanged", "params": {"count": 42}}
```

## Usage

### Simple API (Recommended)

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

// Initialize (optional, auto-initializes on first use)
NativeRPC.init();

// Call methods
final value = await NativeRPC.call<int>('counter.increment');
final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});

// Listen to events (callback style)
NativeRPC.on('counter.countChanged', (data) {
  print('Count: ${data['count']}');
});

// Listen to events (stream style)
NativeRPC.stream('counter.countChanged').listen((data) {
  print('Count: ${data['count']}');
});

// Remove listener
NativeRPC.off('counter.countChanged', myHandler);

// Check connection
final connected = await NativeRPC.ping();

// Clean up
NativeRPC.dispose();
```

## Error Handling

```dart
try {
  final result = await NativeRPC.call<int>('counter.increment');
} on NativeRPCException catch (e) {
  print('Error ${e.code}: ${e.message}');
  
  if (e.code == NativeRPCErrorCode.methodNotFound) {
    // Handle method not found
  }
}
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
| -32003 | timeout | Request timed out |
| -32004 | connectionError | Connection failed |

## Native Side Setup

### iOS (Swift)

```swift
import NativeRPCKit

class CounterService: NativeRPCService {
    override class var serviceName: String { "counter" }
    
    private var count = 0
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // Note: Name is auto-set from serviceName class property
        
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
NativeRPCServiceCenter.shared.register(CounterService.self)
```

### Android (Kotlin)

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.serviceDefinition

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
        
        Function0<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}

// In Application.onCreate() or MainActivity
NativeRPCServiceCenter.register(CounterService.Factory)
```

## Package Structure

```
native_rpc_flutter/
├── lib/
│   ├── native_rpc_flutter.dart      # Main exports
│   └── src/
│       ├── native_rpc.dart          # Simple singleton API
│       ├── runtime/
│       │   ├── native_rpc_connection.dart
│       │   └── native_rpc_message.dart
│       └── connection/
│           └── method_channel_connection.dart
├── ios/                              # iOS plugin glue
└── android/                          # Android plugin glue
```
