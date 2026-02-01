// index.ts
// NativeRPC Web Connection
//
// Main entry point - exports all public APIs

// Core client
export { NativeRPCClient, NativeRPCEventSubscription } from './client';
export type { NativeRPCClientOptions } from './client';

// WebView bridge connection
export {
  WebViewBridgeConnection,
  isNativeRPCAvailable,
  getPlatform,
  waitForBridge,
  onBridgeReady,
} from './webview-bridge';
export type { WebViewBridgeConnectionOptions, Platform } from './webview-bridge';

// Errors
export { NativeRPCError } from './errors';

// Types
export type {
  NativeRPCConnection,
  NativeRPCRequest,
  NativeRPCResponse,
  NativeRPCNotification,
  NativeRPCErrorObject,
  EventHandler,
} from './types';

export { NativeRPCErrorCode } from './types';

// Simple singleton API for convenience
import { NativeRPCClient } from './client';
import { WebViewBridgeConnection, waitForBridge as waitForBridgeFn, isNativeRPCAvailable } from './webview-bridge';
import type { EventHandler } from './types';

let defaultClient: NativeRPCClient | null = null;

/**
 * Simple singleton API for NativeRPC.
 *
 * For most use cases, you can use this API directly without creating
 * a client instance manually.
 *
 * @example
 * ```typescript
 * import { NativeRPC } from '@token-team/nativerpc-web';
 *
 * // Call a method
 * const result = await NativeRPC.call<number>('counter.increment', { step: 1 });
 *
 * // Subscribe to events
 * NativeRPC.on('counter.countChanged', (data) => {
 *   console.log('Count changed:', data);
 * });
 *
 * // Unsubscribe
 * NativeRPC.off('counter.countChanged', handler);
 * ```
 */
export const NativeRPC = {
  /**
   * Initialize the default client with optional configuration.
   * This is called automatically on first use.
   */
  initialize(options?: { timeout?: number; debug?: boolean }): void {
    if (defaultClient) return;

    const connection = new WebViewBridgeConnection({
      debug: options?.debug,
    });

    defaultClient = new NativeRPCClient(connection, options);
  },

  /**
   * Get the default client instance.
   * Creates one if it doesn't exist.
   */
  get client(): NativeRPCClient {
    if (!defaultClient) {
      this.initialize();
    }
    return defaultClient!;
  },

  /**
   * Call a method on a service.
   *
   * @param method - Method in format "service.method"
   * @param params - Optional parameters
   * @returns The result data
   */
  call<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T> {
    return this.client.call<T>(method, params);
  },

  /**
   * Subscribe to an event.
   *
   * @param event - Event in format "service.event"
   * @param handler - Callback for event data
   */
  async on<T = unknown>(event: string, handler: EventHandler<T>): Promise<void> {
    await this.client.subscribe(event, handler);
  },

  /**
   * Unsubscribe from an event.
   *
   * @param event - Event in format "service.event"
   * @param handler - The handler to remove
   */
  off<T = unknown>(event: string, handler: EventHandler<T>): void {
    // Access private method via type assertion
    (this.client as any).unsubscribe(event, handler);
  },

  /**
   * Check if running in a native WebView with NativeRPC support.
   */
  get isAvailable(): boolean {
    return isNativeRPCAvailable();
  },

  /**
   * Wait for the native bridge to be ready.
   *
   * On iOS, the bridge is typically available immediately.
   * On Android, the bridge may not be available until after the page starts loading.
   *
   * @param timeout Maximum time to wait in milliseconds (default: 5000)
   * @returns Promise that resolves when bridge is ready
   *
   * @example
   * ```typescript
   * await NativeRPC.ready();
   * const result = await NativeRPC.call('service.method');
   * ```
   */
  ready(timeout?: number): Promise<void> {
    return waitForBridgeFn(timeout);
  },

  /**
   * Dispose the default client.
   */
  dispose(): void {
    if (defaultClient) {
      defaultClient.dispose();
      defaultClient = null;
    }
  },
};
