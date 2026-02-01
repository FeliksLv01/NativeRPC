# AGENTS - Web Connection

This folder contains the **TypeScript client library** for NativeRPC Web connection, enabling web pages embedded in iOS/Android WebViews to communicate with native code.

## Purpose

The Web connection allows:
- Web pages in WKWebView (iOS) or WebView (Android) to call native RPC methods
- Native code to send events to web pages
- Full JSON-RPC 2.0 protocol support

## Structure

```
web/
├── src/                          # TypeScript client library
│   ├── index.ts                  # Main entry point, exports
│   ├── client.ts                 # NativeRPCClient implementation
│   ├── webview-bridge.ts         # WebView bridge connection
│   ├── types.ts                  # Type definitions
│   └── errors.ts                 # Error classes
│
├── package.json                  # NPM package config
└── tsconfig.json                 # TypeScript config
```

## Native Bridges

The native bridge implementations are now part of the SDK:

- **iOS**: `sdk/ios/Sources/NativeRPCKit/WebView/WebViewNativeRPCBridge.swift`
- **Android**: `sdk/android/src/main/kotlin/com/itoken/team/nativerpc/webview/WebViewNativeRPCBridge.kt`

## Protocol

Uses simplified JSON-RPC 2.0 format:

```json
// Request (Web → Native)
{"id": "uuid", "method": "counter.increment", "params": {"step": 1}}

// Response (Native → Web)
{"id": "uuid", "result": 42}
{"id": "uuid", "error": {"code": -32601, "message": "Method not found"}}

// Event/Notification (Native → Web, no id)
{"method": "counter.countChanged", "params": {"count": 42}}
```

## Web Usage

### Waiting for Bridge Ready

On Android, the JavaScript interface is not available immediately when the page loads. The native bridge dispatches a `nativeRPCBridgeReady` event when ready. Use `waitForBridge()` or `NativeRPC.ready()` to wait for the bridge:

```typescript
import { NativeRPC, waitForBridge } from '@aspect/nativerpc-web';

// Option 1: Using NativeRPC.ready()
await NativeRPC.ready();
const result = await NativeRPC.call('counter.increment', { step: 1 });

// Option 2: Using waitForBridge() with timeout
try {
  await waitForBridge(3000); // Wait up to 3 seconds
  console.log('Bridge is ready!');
} catch (e) {
  console.log('Not running in WebView');
}

// Option 3: Using event listener directly
window.addEventListener('nativeRPCBridgeReady', () => {
  console.log('Bridge is ready!');
});
```

**Note:** On iOS, the bridge is typically available immediately (injected at document start via `WKUserScript`). On Android, the bridge is available after the page starts loading.

### Simple API

```typescript
import { NativeRPC } from '@aspect/nativerpc-web';

// Wait for bridge (important on Android!)
await NativeRPC.ready();

// Call a method
const result = await NativeRPC.call<number>('counter.increment', { step: 1 });

// Subscribe to events
NativeRPC.on('counter.countChanged', (data) => {
  console.log('Count changed:', data.count);
});
```

### Advanced API

```typescript
import { NativeRPCClient, WebViewBridgeConnection } from '@aspect/nativerpc-web';

const connection = new WebViewBridgeConnection({
  debug: true,
  iosHandlerName: 'nativeRPC',      // Custom handler name
  androidInterfaceName: 'NativeRPC', // Custom interface name
});

const client = new NativeRPCClient(connection, {
  timeout: 30000,
  debug: true,
});

// Call methods
const result = await client.call<number>('counter.increment', { step: 1 });

// Subscribe to events
const subscription = await client.subscribe('counter.countChanged', (data) => {
  console.log('Count:', data.count);
});

// Unsubscribe later
await subscription.cancel();

// Async iterator for events
for await (const data of client.events('counter.countChanged')) {
  console.log('Count:', data.count);
}
```

## iOS Integration (Swift)

The native bridge is now included in NativeRPCKit SDK.

```swift
import WebKit
import NativeRPCKit

class ViewController: UIViewController {
    let webView = WKWebView()
    let rpcHost = NativeRPCHost()
    var bridge: WebViewNativeRPCBridge?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register services
        rpcHost.register(CounterService())
        
        // Create and attach bridge
        bridge = WebViewNativeRPCBridge(webView: webView, host: rpcHost)
        bridge?.attach()
        
        // Enable debugging
        bridge?.debugEnabled = true
        
        // Load web content
        webView.load(URLRequest(url: URL(string: "https://example.com")!))
    }
    
    deinit {
        bridge?.detach()
    }
}
```

### iOS JavaScript Bridge

The bridge registers a WKScriptMessageHandler with the name "nativeRPC" (configurable).

**Bridge Ready:**
- iOS injects a `WKUserScript` at document start that sets `window.__nativeRPCBridgeReady = true`
- Dispatches `nativeRPCBridgeReady` event when DOM is ready
- Bridge is typically available immediately

**JavaScript → Native:**
```javascript
window.webkit.messageHandlers.nativeRPC.postMessage(jsonString);
```

**Native → JavaScript:**
```javascript
window.__nativeRPCCallbacks.onMessage(jsonString);
```

## Android Integration (Kotlin)

The native bridge is now included in NativeRPC SDK.

```kotlin
import android.webkit.WebView
import com.itoken.team.nativerpc.core.NativeRPCHost
import com.itoken.team.nativerpc.webview.WebViewNativeRPCBridge

class MainActivity : AppCompatActivity() {
    private lateinit var webView: WebView
    private val rpcHost = NativeRPCHost()
    private var bridge: WebViewNativeRPCBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        webView = findViewById(R.id.webView)
        
        // Enable JavaScript
        webView.settings.javaScriptEnabled = true
        
        // Register services
        rpcHost.register(CounterService())
        
        // Create and attach bridge
        bridge = WebViewNativeRPCBridge(webView, rpcHost)
        bridge?.debugEnabled = true
        bridge?.attach()
        
        // Load web content
        webView.loadUrl("https://example.com")
    }
    
    override fun onDestroy() {
        bridge?.detach()
        super.onDestroy()
    }
}
```

### Android JavaScript Bridge

The bridge adds a JavaScript interface with the name "NativeRPC" (configurable).

**Bridge Ready:**
- Android's `@JavascriptInterface` is only available after the page starts loading
- The bridge sets a `WebViewClient` that dispatches `nativeRPCBridgeReady` event on `onPageStarted` and `onPageFinished`
- **Important:** Web code should wait for this event before making RPC calls

**JavaScript → Native:**
```javascript
window.NativeRPC.postMessage(jsonString);
```

**Native → JavaScript:**
```javascript
window.__nativeRPCCallbacks.onMessage(jsonString);
```

## Platform Detection

The TypeScript client automatically detects the platform:

```typescript
import { getPlatform, isNativeRPCAvailable } from '@aspect/nativerpc-web';

console.log(getPlatform());        // 'ios', 'android', or 'unknown'
console.log(isNativeRPCAvailable()); // true if running in WebView with bridge
```

## Iframe Support

The web connection supports iframes. Each iframe creates its own `NativeRPCClient` with a unique `frameId`, and responses are automatically routed back to the correct frame.

### How It Works

1. **Each frame generates a unique `frameId`** when creating a `WebViewBridgeConnection`
2. **The `frameId` is included in every request** sent to native
3. **Native bridges track the `frameId`** for each request and include it in the response
4. **The JavaScript client routes responses** to the correct frame based on `frameId`

### Usage in Iframes

```typescript
// In your iframe - works exactly the same as in main frame
import { NativeRPC } from '@aspect/nativerpc-web';

await NativeRPC.ready();
const result = await NativeRPC.call('counter.increment', { step: 1 });
```

### Protocol Extension

Messages include an optional `frameId` field:

```json
// Request from iframe
{"id": "1", "method": "counter.increment", "params": {"step": 1}, "frameId": "frame-123456789-abc"}

// Response routed back to same frame
{"id": "1", "result": 42, "frameId": "frame-123456789-abc"}
```

### Notes

- Events (notifications) can also include `frameId` if you want to target specific frames
- If no `frameId` is present in a response, it's broadcast to all frames (backwards compatibility)
- Each `WebViewBridgeConnection` instance has a unique `frameId` accessible via `connection.frameId`

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

## Build

```bash
# Install dependencies
npm install

# Build library
npm run build

# Development (watch mode)
npm run dev

# Type check
npm run typecheck
```

## Files Reference

### TypeScript Client
- `src/index.ts` - Main exports and simple NativeRPC singleton API
- `src/client.ts` - Full NativeRPCClient with subscriptions and async iterators
- `src/webview-bridge.ts` - WebViewBridgeConnection for iOS/Android detection
- `src/types.ts` - Type definitions (NativeRPCConnection interface, messages)
- `src/errors.ts` - NativeRPCError class with standard error constructors

### Native Bridges (in SDK)
- `sdk/ios/Sources/NativeRPCKit/WebView/WebViewNativeRPCBridge.swift` - iOS WKWebView bridge
- `sdk/android/src/main/kotlin/com/itoken/team/nativerpc/webview/WebViewNativeRPCBridge.kt` - Android WebView bridge

## Security Considerations

1. **JavaScript Interface Security**: Only add the JavaScript interface to WebViews loading trusted content
2. **CORS**: Ensure your web server allows requests from the WebView
3. **HTTPS**: Use HTTPS for production web content
4. **Input Validation**: Validate all incoming RPC parameters on the native side

## Related Documentation

- Main README: `../../README.md`
- iOS SDK: `../../sdk/ios/`
- Android SDK: `../../sdk/android/`
- Flutter Connection: `../flutter/`
- Protocol Docs: `../../docs/ARCHITECTURE.md`
