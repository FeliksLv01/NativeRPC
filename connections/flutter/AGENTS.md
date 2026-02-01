# AGENTS - Flutter Connection

This folder contains the Flutter connection implementation for NativeRPC.

## Structure

```
flutter/
└── native_rpc_flutter/           # Single Flutter plugin package
    ├── lib/
    │   ├── native_rpc_flutter.dart     # Package export
    │   └── src/
    │       ├── native_rpc.dart         # Simple singleton API (NativeRPC.call, NativeRPC.on)
    │       ├── runtime/
    │       │   ├── native_rpc_client.dart    # Advanced client with full control
    │       │   ├── native_rpc_message.dart   # Message models & error codes
    │       │   └── native_rpc_connection.dart # Connection interface
    │       └── connection/
    │           └── method_channel_connection.dart  # MethodChannel implementation
    ├── ios/Classes/
    │   └── FlutterMethodChannelConnection.swift    # iOS MethodChannel handler
    └── android/
        └── src/.../NativeRpcFlutterPlugin.kt       # Android MethodChannel handler
```

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

### Simple API (Recommended)

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

### Advanced API

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

// Create custom client
final client = NativeRPCClient(MethodChannelConnection());

// Call with full response
final response = await client.call(
  NativeRPCRequest(id: '1', method: 'counter.increment', params: {}),
);

if (response.hasError) {
  print('Error: ${response.error!.message}');
} else {
  print('Result: ${response.result}');
}

// Listen to events
client.events.listen((event) {
  print('Event: ${event.method} - ${event.params}');
});
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
| -32005 | unknown | Unknown error |

## iOS Integration

The iOS side (`ios/Classes/FlutterMethodChannelConnection.swift`) handles:
1. Receiving MethodChannel calls from Flutter
2. Forwarding to `NativeRPCHost` for processing
3. Sending responses back via MethodChannel result
4. Pushing events to Flutter via `invokeMethod("notification", ...)`

## Android Integration

The Android side (`android/...`) provides the same functionality in Kotlin.

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

## Related Files

- iOS SDK: `../../sdk/ios/`
- Example app: `../../examples/flutter_counter/`
- Main README: `../../README.md`
