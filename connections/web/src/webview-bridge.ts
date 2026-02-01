// webview-bridge.ts
// NativeRPC Web Connection
//
// WebView Bridge connection for iOS (WKWebView) and Android (WebView)

import { NativeRPCConnection } from './types';

/**
 * Platform detection
 */
export type Platform = 'ios' | 'android' | 'unknown';

/**
 * Detect the current platform by checking for native bridge availability
 */
function detectPlatform(): Platform {
  if (typeof window === 'undefined') return 'unknown';
  
  // Check for iOS WKWebView
  if ((window as any).webkit?.messageHandlers?.nativeRPC) {
    return 'ios';
  }
  
  // Check for Android WebView
  if ((window as any).NativeRPC) {
    return 'android';
  }
  
  return 'unknown';
}

/**
 * Check if the bridge is already ready
 */
function isBridgeReady(): boolean {
  if (typeof window === 'undefined') return false;
  return (window as any).__nativeRPCBridgeReady === true;
}

/**
 * iOS WKWebView bridge interface
 */
interface WKWebViewBridge {
  webkit: {
    messageHandlers: {
      nativeRPC: {
        postMessage(message: string): void;
      };
    };
  };
}

/**
 * Android WebView bridge interface
 */
interface AndroidWebViewBridge {
  NativeRPC: {
    postMessage(message: string): string | void;
  };
}

/**
 * Global callback registry for async responses
 */
declare global {
  interface Window {
    __nativeRPCCallbacks?: {
      onMessage?: (message: string) => void;
      /** Registry of frame callbacks by frameId */
      frames?: Map<string, (message: string) => void>;
    };
    __nativeRPCBridgeReady?: boolean;
    /** Unique frame ID for this window/iframe */
    __nativeRPCFrameId?: string;
  }
}

/**
 * Generate a unique frame ID for this window/iframe
 */
function generateFrameId(): string {
  // Try to reuse existing frameId if page was reloaded
  if (typeof window !== 'undefined' && window.__nativeRPCFrameId) {
    return window.__nativeRPCFrameId;
  }
  
  const frameId = `frame-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
  
  if (typeof window !== 'undefined') {
    window.__nativeRPCFrameId = frameId;
  }
  
  return frameId;
}

/**
 * Configuration options for WebViewBridgeConnection
 */
export interface WebViewBridgeConnectionOptions {
  /** 
   * Handler name for iOS WKWebView (default: 'nativeRPC')
   * This should match the name used in WKUserContentController.add(handler, name:)
   */
  iosHandlerName?: string;
  
  /**
   * JavaScript interface name for Android WebView (default: 'NativeRPC')
   * This should match the name used in webView.addJavascriptInterface(obj, name)
   */
  androidInterfaceName?: string;
  
  /**
   * Custom connection ID
   */
  id?: string;

  /**
   * Enable debug logging
   */
  debug?: boolean;
}

/**
 * WebView Bridge connection for iOS (WKWebView) and Android (WebView).
 *
 * This connection allows web pages embedded in native WebViews to communicate
 * with the native NativeRPC host.
 *
 * ## iOS Setup (Swift)
 *
 * ```swift
 * import WebKit
 *
 * class ViewController: UIViewController {
 *     let webView: WKWebView = ...
 *     let rpcHost: NativeRPCHost = ...
 *
 *     override func viewDidLoad() {
 *         super.viewDidLoad()
 *         
 *         // Create bridge
 *         let bridge = WebViewNativeRPCBridge(webView: webView, host: rpcHost)
 *         
 *         // Register with WKWebView
 *         webView.configuration.userContentController.add(bridge, name: "nativeRPC")
 *     }
 * }
 * ```
 *
 * ## Android Setup (Kotlin)
 *
 * ```kotlin
 * class MainActivity : AppCompatActivity() {
 *     private lateinit var webView: WebView
 *     private lateinit var rpcHost: NativeRPCHost
 *
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         
 *         // Create bridge
 *         val bridge = WebViewNativeRPCBridge(webView, rpcHost)
 *         
 *         // Register with WebView
 *         webView.addJavascriptInterface(bridge, "NativeRPC")
 *     }
 * }
 * ```
 *
 * ## Web Usage
 *
 * ```typescript
 * import { WebViewBridgeConnection, NativeRPCClient } from '@token-team/nativerpc-web';
 *
 * const connection = new WebViewBridgeConnection();
 * const client = new NativeRPCClient(connection);
 *
 * // Call native method
 * const result = await client.call('counter.increment', { step: 1 });
 *
 * // Subscribe to events
 * await client.subscribe('counter.countChanged', (data) => {
 *   console.log('Count changed:', data);
 * });
 * ```
 */
export class WebViewBridgeConnection implements NativeRPCConnection {
  readonly id: string;
  readonly platform: Platform;
  /** Unique frame ID for this window/iframe */
  readonly frameId: string;
  
  private iosHandlerName: string;
  private androidInterfaceName: string;
  private debug: boolean;
  
  private messageHandlers = new Set<(message: string) => void>();
  private active = true;

  constructor(options: WebViewBridgeConnectionOptions = {}) {
    this.id = options.id ?? `webview-${Date.now()}`;
    this.frameId = generateFrameId();
    this.iosHandlerName = options.iosHandlerName ?? 'nativeRPC';
    this.androidInterfaceName = options.androidInterfaceName ?? 'NativeRPC';
    this.debug = options.debug ?? false;
    
    this.platform = detectPlatform();
    this.log('Detected platform:', this.platform);
    
    this.setupGlobalCallback();
  }

  /**
   * Setup global callback for native to send messages to web.
   * 
   * For iframe support, we register this frame's callback in a global registry.
   * Native will call onMessage with a frameId, and we route to the correct frame.
   */
  private setupGlobalCallback(): void {
    if (typeof window === 'undefined') return;

    window.__nativeRPCCallbacks = window.__nativeRPCCallbacks ?? {};
    
    // Initialize frames registry if not exists
    if (!window.__nativeRPCCallbacks.frames) {
      window.__nativeRPCCallbacks.frames = new Map();
    }
    
    // Register this frame's callback
    window.__nativeRPCCallbacks.frames.set(this.frameId, (message: string) => {
      this.handleIncomingMessage(message);
    });
    
    this.log('Registered frame callback with frameId:', this.frameId);
    
    // Set up the global onMessage handler (only once per window)
    // This handler routes messages to the correct frame based on frameId
    if (!window.__nativeRPCCallbacks.onMessage) {
      window.__nativeRPCCallbacks.onMessage = (message: string) => {
        try {
          const parsed = JSON.parse(message);
          const targetFrameId = parsed.frameId;
          
          if (targetFrameId && window.__nativeRPCCallbacks?.frames) {
            // Route to specific frame
            const frameCallback = window.__nativeRPCCallbacks.frames.get(targetFrameId);
            if (frameCallback) {
              frameCallback(message);
            } else {
              console.warn(`[NativeRPC] No handler for frameId: ${targetFrameId}`);
            }
          } else {
            // No frameId - broadcast to all frames (for backwards compatibility)
            window.__nativeRPCCallbacks?.frames?.forEach((callback) => {
              callback(message);
            });
          }
        } catch (e) {
          // Parse error - broadcast to all frames
          window.__nativeRPCCallbacks?.frames?.forEach((callback) => {
            callback(message);
          });
        }
      };
    }
  }
  
  /**
   * Handle incoming message for this frame
   */
  private handleIncomingMessage(message: string): void {
    this.log('Received from native:', message);
    
    for (const handler of this.messageHandlers) {
      try {
        handler(message);
      } catch (e) {
        console.error('[NativeRPC] Error in message handler:', e);
      }
    }
  }

  get isActive(): boolean {
    return this.active && this.platform !== 'unknown';
  }

  /**
   * Send a message to native.
   * 
   * Automatically injects frameId into the message for routing responses back.
   * 
   * @returns Response string if native returns synchronously, null otherwise
   */
  async send(message: string): Promise<string | null> {
    if (!this.active) {
      throw new Error('Connection is closed');
    }

    // Inject frameId into the message
    const messageWithFrameId = this.injectFrameId(message);
    
    this.log('Sending to native:', messageWithFrameId);

    if (this.platform === 'ios') {
      return this.sendToiOS(messageWithFrameId);
    } else if (this.platform === 'android') {
      return this.sendToAndroid(messageWithFrameId);
    } else {
      throw new Error('No native bridge available. Are you running in a WebView?');
    }
  }
  
  /**
   * Inject frameId into an outgoing message
   */
  private injectFrameId(message: string): string {
    try {
      const parsed = JSON.parse(message);
      parsed.frameId = this.frameId;
      return JSON.stringify(parsed);
    } catch {
      // If parsing fails, return original message
      return message;
    }
  }

  private sendToiOS(message: string): null {
    const bridge = window as unknown as WKWebViewBridge;
    
    // Access handler dynamically to support custom names
    const handler = (bridge.webkit?.messageHandlers as any)?.[this.iosHandlerName];
    
    if (!handler) {
      throw new Error(`iOS handler '${this.iosHandlerName}' not found`);
    }
    
    // WKWebView message handlers are async, response comes via callback
    handler.postMessage(message);
    return null;
  }

  private sendToAndroid(message: string): string | null {
    const bridge = window as unknown as AndroidWebViewBridge;
    
    // Access interface dynamically to support custom names
    const nativeInterface = (window as any)[this.androidInterfaceName];
    
    if (!nativeInterface) {
      throw new Error(`Android interface '${this.androidInterfaceName}' not found`);
    }
    
    // Android can return synchronously
    const result = nativeInterface.postMessage(message);
    
    if (typeof result === 'string' && result.length > 0) {
      this.log('Sync response from Android:', result);
      return result;
    }
    
    return null;
  }

  onMessage(handler: (message: string) => void): () => void {
    this.messageHandlers.add(handler);
    
    return () => {
      this.messageHandlers.delete(handler);
    };
  }

  async ping(): Promise<boolean> {
    if (!this.active || this.platform === 'unknown') {
      return false;
    }
    
    try {
      // Send a ping request and check if native responds
      const request = JSON.stringify({ id: 'ping', method: 'rpc.ping', params: {} });
      await this.send(request);
      return true;
    } catch {
      return false;
    }
  }

  close(): void {
    if (!this.active) return;
    this.active = false;
    
    this.messageHandlers.clear();
    
    // Unregister from frames registry
    if (typeof window !== 'undefined' && window.__nativeRPCCallbacks?.frames) {
      window.__nativeRPCCallbacks.frames.delete(this.frameId);
      this.log('Unregistered frame callback for frameId:', this.frameId);
    }
  }

  private log(...args: unknown[]): void {
    if (this.debug) {
      console.log('[NativeRPC WebView]', ...args);
    }
  }
}

/**
 * Check if running in a native WebView with NativeRPC support
 */
export function isNativeRPCAvailable(): boolean {
  return detectPlatform() !== 'unknown';
}

/**
 * Get the current platform
 */
export function getPlatform(): Platform {
  return detectPlatform();
}

/**
 * Wait for the native bridge to be ready.
 *
 * On iOS, the bridge is typically available immediately (injected at document start).
 * On Android, the bridge may not be available until after the page starts loading,
 * so the native side dispatches a 'nativeRPCBridgeReady' event when ready.
 *
 * @param timeout Maximum time to wait in milliseconds (default: 5000)
 * @returns Promise that resolves when bridge is ready, or rejects on timeout
 *
 * @example
 * ```typescript
 * // Wait for bridge before making calls
 * await waitForBridge();
 * const result = await NativeRPC.call('service.method');
 * ```
 *
 * @example
 * ```typescript
 * // With timeout
 * try {
 *   await waitForBridge(3000);
 *   console.log('Bridge is ready');
 * } catch (e) {
 *   console.log('Not running in WebView or bridge not available');
 * }
 * ```
 */
export function waitForBridge(timeout: number = 5000): Promise<void> {
  return new Promise((resolve, reject) => {
    // If already ready, resolve immediately
    if (isBridgeReady() || isNativeRPCAvailable()) {
      resolve();
      return;
    }

    // Set up timeout
    const timeoutId = setTimeout(() => {
      window.removeEventListener('nativeRPCBridgeReady', onReady);
      reject(new Error(`Bridge not ready within ${timeout}ms. Are you running in a WebView?`));
    }, timeout);

    // Listen for ready event
    function onReady() {
      clearTimeout(timeoutId);
      window.removeEventListener('nativeRPCBridgeReady', onReady);
      resolve();
    }

    window.addEventListener('nativeRPCBridgeReady', onReady);
  });
}

/**
 * Register a callback to be called when the bridge is ready.
 *
 * This is an alternative to `waitForBridge()` for callback-style code.
 *
 * @param callback Function to call when bridge is ready
 * @returns Cleanup function to remove the listener
 *
 * @example
 * ```typescript
 * onBridgeReady(() => {
 *   console.log('Bridge is ready!');
 *   NativeRPC.call('service.method').then(console.log);
 * });
 * ```
 */
export function onBridgeReady(callback: () => void): () => void {
  // If already ready, call immediately
  if (isBridgeReady() || isNativeRPCAvailable()) {
    // Use setTimeout to ensure callback is always async
    setTimeout(callback, 0);
    return () => {};
  }

  // Listen for ready event
  function onReady() {
    window.removeEventListener('nativeRPCBridgeReady', onReady);
    callback();
  }

  window.addEventListener('nativeRPCBridgeReady', onReady);

  return () => {
    window.removeEventListener('nativeRPCBridgeReady', onReady);
  };
}
