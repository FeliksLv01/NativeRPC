// index.ts
// NativeRPC Web SDK
//
// Simple singleton API for WebView communication with native iOS/Android

import { NativeRPCError } from './errors';
import {
  NativeRPCRequest,
  NativeRPCResponse,
  NativeRPCNotification,
  EventHandler,
} from './types';
import {
  WebViewBridgeConnection,
  isNativeRPCAvailable as checkNativeRPCAvailable,
  waitForBridge as waitForBridgeFn,
} from './webview-bridge';

// Re-export utilities and types
export {
  isNativeRPCAvailable,
  getPlatform,
  waitForBridge,
  onBridgeReady,
} from './webview-bridge';
export type { Platform, WebViewBridgeConnectionOptions } from './webview-bridge';

export { NativeRPCError } from './errors';
export type {
  NativeRPCRequest,
  NativeRPCResponse,
  NativeRPCNotification,
  NativeRPCErrorObject,
  EventHandler,
} from './types';
export { NativeRPCErrorCode } from './types';

/**
 * Configuration options for NativeRPC
 */
export interface NativeRPCOptions {
  /** Timeout for RPC calls in milliseconds (default: 30000) */
  timeout?: number;
  /** Enable debug logging (default: false) */
  debug?: boolean;
}

/**
 * Generate a unique ID
 */
function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Internal state for NativeRPC singleton
 */
interface NativeRPCState {
  connection: WebViewBridgeConnection | null;
  timeout: number;
  debug: boolean;
  disposed: boolean;
  pendingRequests: Map<
    string,
    {
      resolve: (response: NativeRPCResponse) => void;
      reject: (error: Error) => void;
      timeoutId: ReturnType<typeof setTimeout>;
    }
  >;
  eventHandlers: Map<string, Set<EventHandler>>;
  unsubscribeMessages: (() => void) | null;
}

const state: NativeRPCState = {
  connection: null,
  timeout: 30000,
  debug: false,
  disposed: false,
  pendingRequests: new Map(),
  eventHandlers: new Map(),
  unsubscribeMessages: null,
};

/**
 * Log message if debug is enabled
 */
function log(...args: unknown[]): void {
  if (state.debug) {
    console.log('[NativeRPC]', ...args);
  }
}

/**
 * Ensure connection is initialized
 */
function ensureConnection(): WebViewBridgeConnection {
  if (state.disposed) {
    throw NativeRPCError.connectionError('NativeRPC has been disposed');
  }
  
  if (!state.connection) {
    state.connection = new WebViewBridgeConnection({ debug: state.debug });
    setupMessageHandler();
  }
  
  return state.connection;
}

/**
 * Setup message handler for incoming messages
 */
function setupMessageHandler(): void {
  if (!state.connection) return;
  
  state.unsubscribeMessages = state.connection.onMessage((message) => {
    handleMessage(message);
  });
}

/**
 * Handle incoming message from native
 */
function handleMessage(message: string): void {
  try {
    const json = JSON.parse(message);

    // Check if this is a notification (no id) or response (has id)
    if (!('id' in json)) {
      // It's a notification (event)
      handleNotification(json as NativeRPCNotification);
    } else {
      // It's a response
      handleResponse(json as NativeRPCResponse);
    }
  } catch (e) {
    log('Error handling message:', e);
  }
}

/**
 * Handle response from native
 */
function handleResponse(response: NativeRPCResponse): void {
  const pending = state.pendingRequests.get(response.id);
  if (pending) {
    clearTimeout(pending.timeoutId);
    state.pendingRequests.delete(response.id);
    pending.resolve(response);
  }
}

/**
 * Handle notification (event) from native
 */
function handleNotification(notification: NativeRPCNotification): void {
  const handlers = state.eventHandlers.get(notification.method);
  if (handlers) {
    for (const handler of handlers) {
      try {
        handler(notification.params);
      } catch (e) {
        log('Error in event handler:', e);
      }
    }
  }
}

/**
 * Send subscribe request to native
 */
async function sendSubscribe(event: string): Promise<void> {
  const connection = ensureConnection();
  const request = {
    id: generateId(),
    method: 'rpc.subscribe' as const,
    params: { event },
  };
  
  try {
    await connection.send(JSON.stringify(request));
    log('Subscribed to event:', event);
  } catch (e) {
    log('Error subscribing to event:', e);
    throw e;
  }
}

/**
 * Send unsubscribe request to native
 */
async function sendUnsubscribe(event: string): Promise<void> {
  if (state.disposed || !state.connection) return;
  
  const request = {
    id: generateId(),
    method: 'rpc.unsubscribe' as const,
    params: { event },
  };
  
  try {
    await state.connection.send(JSON.stringify(request));
    log('Unsubscribed from event:', event);
  } catch (e) {
    log('Error unsubscribing from event:', e);
  }
}

/**
 * Simple singleton API for NativeRPC.
 *
 * @example
 * ```typescript
 * import { NativeRPC } from '@token-team/nativerpc-web';
 *
 * // Wait for bridge to be ready (important on Android)
 * await NativeRPC.ready();
 *
 * // Call a method
 * const result = await NativeRPC.call<number>('counter.increment');
 *
 * // Subscribe to events
 * NativeRPC.on('counter.countChanged', (data) => {
 *   console.log('Count changed:', data.count);
 * });
 *
 * // Unsubscribe
 * NativeRPC.off('counter.countChanged', handler);
 * ```
 */
export const NativeRPC = {
  /**
   * Initialize NativeRPC with optional configuration.
   * This is called automatically on first use.
   */
  init(options?: NativeRPCOptions): void {
    if (state.connection) return;

    state.timeout = options?.timeout ?? 30000;
    state.debug = options?.debug ?? false;
    state.disposed = false;

    ensureConnection();
  },

  /**
   * Call a method on a native service.
   *
   * @param method - Method in format "service.method"
   * @param params - Optional parameters
   * @returns The result data
   * @throws {NativeRPCError} on failure
   *
   * @example
   * ```typescript
   * const count = await NativeRPC.call<number>('counter.increment');
   * const sum = await NativeRPC.call<number>('counter.add', { value: 5 });
   * ```
   */
  async call<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T> {
    const connection = ensureConnection();

    const request: NativeRPCRequest = {
      id: generateId(),
      method,
      ...(params !== undefined && { params }),
    };

    const requestStr = JSON.stringify(request);
    log('Sending request:', request);

    // Try synchronous response first (some bridges support it)
    const syncResponse = await connection.send(requestStr);

    if (syncResponse) {
      const response = JSON.parse(syncResponse) as NativeRPCResponse;
      log('Received sync response:', response);

      if (response.error) {
        throw NativeRPCError.fromErrorObject(response.error);
      }

      return response.result as T;
    }

    // Wait for async response
    return new Promise<T>((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        state.pendingRequests.delete(request.id);
        reject(NativeRPCError.timeout(`Method call ${method} timed out`));
      }, state.timeout);

      state.pendingRequests.set(request.id, {
        resolve: (response) => {
          log('Received async response:', response);

          if (response.error) {
            reject(NativeRPCError.fromErrorObject(response.error));
          } else {
            resolve(response.result as T);
          }
        },
        reject,
        timeoutId,
      });
    });
  },

  /**
   * Subscribe to an event.
   *
   * @param event - Event in format "service.event"
   * @param handler - Callback for event data
   *
   * @example
   * ```typescript
   * NativeRPC.on('counter.countChanged', (data) => {
   *   console.log('Count:', data.count);
   * });
   * ```
   */
  on<T = unknown>(event: string, handler: EventHandler<T>): void {
    ensureConnection();

    let handlers = state.eventHandlers.get(event);
    const isFirstSubscriber = !handlers || handlers.size === 0;

    if (!handlers) {
      handlers = new Set();
      state.eventHandlers.set(event, handlers);
    }
    handlers.add(handler as EventHandler);

    if (isFirstSubscriber) {
      // Send subscribe request to native (fire and forget)
      sendSubscribe(event).catch((e) => {
        log('Failed to subscribe:', e);
      });
    }
  },

  /**
   * Unsubscribe from an event.
   *
   * @param event - Event in format "service.event"
   * @param handler - The handler to remove
   *
   * @example
   * ```typescript
   * NativeRPC.off('counter.countChanged', myHandler);
   * ```
   */
  off<T = unknown>(event: string, handler: EventHandler<T>): void {
    const handlers = state.eventHandlers.get(event);
    if (!handlers) return;

    handlers.delete(handler as EventHandler);

    if (handlers.size === 0) {
      state.eventHandlers.delete(event);
      // Send unsubscribe request to native (fire and forget)
      sendUnsubscribe(event).catch((e) => {
        log('Failed to unsubscribe:', e);
      });
    }
  },

  /**
   * Check if running in a native WebView with NativeRPC support.
   */
  get isAvailable(): boolean {
    return checkNativeRPCAvailable();
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
   * Dispose NativeRPC and clean up resources.
   */
  dispose(): void {
    if (state.disposed) return;
    state.disposed = true;

    // Reject all pending requests
    for (const [id, pending] of state.pendingRequests) {
      clearTimeout(pending.timeoutId);
      pending.reject(NativeRPCError.connectionError('NativeRPC disposed'));
    }
    state.pendingRequests.clear();

    // Clear event handlers
    state.eventHandlers.clear();

    // Unsubscribe from messages
    state.unsubscribeMessages?.();
    state.unsubscribeMessages = null;

    // Close connection
    state.connection?.close();
    state.connection = null;
  },
};
