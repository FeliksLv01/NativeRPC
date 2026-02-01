# AGENTS - Connection Layer

This folder contains **connection layer implementations** for NativeRPC.

## Purpose

The connection layer provides transport mechanisms for the NativeRPC protocol. Different transports can be used depending on the use case.

## Structure

```
connections/
├── flutter/
│   └── native_rpc_flutter/     # Flutter plugin with Dart SDK + MethodChannel
│       ├── lib/
│       │   ├── native_rpc_flutter.dart    # Package export
│       │   └── src/
│       │       ├── native_rpc.dart        # Simple singleton API
│       │       ├── runtime/               # Core client & message models
│       │       └── connection/            # MethodChannel transport
│       ├── ios/Classes/                   # iOS plugin (Swift)
│       └── android/                       # Android plugin (Kotlin)
│
└── web/
    ├── src/                    # TypeScript client library
    │   ├── index.ts            # Main exports + NativeRPC singleton
    │   ├── client.ts           # NativeRPCClient implementation
    │   ├── webview-bridge.ts   # WebView bridge with platform detection
    │   ├── types.ts            # Type definitions
    │   └── errors.ts           # Error classes
    ├── ios/                    # iOS WKWebView bridge (Swift)
    ├── android/                # Android WebView bridge (Kotlin)
    ├── package.json            # NPM package config
    └── tsconfig.json           # TypeScript config
```

## Current Implementations

### Flutter (MethodChannel)
- **Location**: `flutter/native_rpc_flutter/`
- **Transport**: Flutter MethodChannel
- **Use Case**: Flutter apps communicating with iOS/Android native code
- **Protocol**: Simplified JSON-RPC 2.0

### Web (WebView Bridge)
- **Location**: `web/`
- **Transport**: JavaScript bridge (WKWebView on iOS, WebView on Android)
- **Use Case**: Web pages embedded in native WebViews communicating with native code
- **Protocol**: Simplified JSON-RPC 2.0
- **NPM Package**: `@token-team/nativerpc-web`

## Protocol Format

All connections use the simplified JSON-RPC 2.0 format:

```json
// Request (client → server)
{"id": "1", "method": "service.method", "params": {...}}

// Response (server → client)
{"id": "1", "result": ...}
{"id": "1", "error": {"code": -32601, "message": "Method not found"}}

// Notification/Event (server → client, no id)
{"method": "service.eventName", "params": {...}}
```

## Planned Implementations

### WebSocket
- **Future**: `websocket/`
- **Use Case**: Remote communication, development tools, browser apps outside WebView

### HTTP/REST
- **Future**: `http/`
- **Use Case**: Remote procedure calls over HTTP

### Custom
- Developers can implement their own by:
  1. Implementing `NativeRPCConnection` interface (Dart)
  2. Handling JSON message serialization/deserialization
  3. Connecting to native SDK's `NativeRPCHost`

## Design Principles

1. **Pluggable**: Any transport can be used
2. **Protocol-Agnostic**: Connection layer just moves JSON messages
3. **Bidirectional**: Supports calls (client→server) and events (server→client)
4. **Single Channel**: One connection handles all services

## Adding New Connections

To add a new connection type (e.g., WebSocket):

1. Create directory: `connections/websocket/`
2. Implement client side:
   - Dart: Implement `NativeRPCConnection` interface
   - TypeScript/JS: Create client that follows JSON-RPC 2.0 format
3. Implement native side:
   - iOS: Implement `NativeRPCConnection` protocol
   - Android: Implement `NativeRPCConnection` interface
4. Add example usage
5. Create `AGENTS.md` in new directory

## Related Documentation

- Main README: `../README.md`
- Architecture: `../docs/ARCHITECTURE.md`
- Native SDKs: `../sdk/`
