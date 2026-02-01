// client.ts
// NativeRPC Web Connection
//
// RPC client for Web using simplified JSON-RPC 2.0 protocol

import { NativeRPCError } from './errors';
import {
  NativeRPCConnection,
  NativeRPCRequest,
  NativeRPCResponse,
  NativeRPCNotification,
  EventHandler,
} from './types';

/**
 * Generate a unique ID
 */
function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

/**
 * Event subscription that can be cancelled
 */
export class NativeRPCEventSubscription {
  private client: NativeRPCClient;
  private event: string;
  private handler: EventHandler;
  private cancelled = false;

  constructor(client: NativeRPCClient, event: string, handler: EventHandler) {
    this.client = client;
    this.event = event;
    this.handler = handler;
  }

  /**
   * Cancel the subscription
   */
  async cancel(): Promise<void> {
    if (this.cancelled) return;
    this.cancelled = true;
    await this.client['unsubscribe'](this.event, this.handler);
  }

  /**
   * Whether the subscription has been cancelled
   */
  get isCancelled(): boolean {
    return this.cancelled;
  }
}

/**
 * Configuration options for NativeRPCClient
 */
export interface NativeRPCClientOptions {
  /** Timeout for RPC calls in milliseconds (default: 30000) */
  timeout?: number;
  /** Enable debug logging (default: false) */
  debug?: boolean;
}

/**
 * The NativeRPC client for Web.
 *
 * Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)
 *
 * @example
 * ```typescript
 * const connection = new WebViewBridgeConnection();
 * const client = new NativeRPCClient(connection);
 *
 * // Call a method
 * const result = await client.call<number>('counter.increment', { step: 1 });
 *
 * // Subscribe to events
 * const subscription = await client.subscribe('counter.countChanged', (data) => {
 *   console.log('Count changed:', data);
 * });
 *
 * // Unsubscribe later
 * await subscription.cancel();
 * ```
 */
export class NativeRPCClient {
  private connection: NativeRPCConnection;
  private timeout: number;
  private debug: boolean;

  /** Pending request resolvers by request ID */
  private pendingRequests = new Map<
    string,
    {
      resolve: (response: NativeRPCResponse) => void;
      reject: (error: Error) => void;
      timeoutId: ReturnType<typeof setTimeout>;
    }
  >();

  /** Event subscriptions by "service.event" key */
  private eventHandlers = new Map<string, Set<EventHandler>>();

  /** Message listener unsubscribe function */
  private unsubscribeMessages: (() => void) | null = null;

  /** Whether the client has been disposed */
  private disposed = false;

  constructor(connection: NativeRPCConnection, options: NativeRPCClientOptions = {}) {
    this.connection = connection;
    this.timeout = options.timeout ?? 30000;
    this.debug = options.debug ?? false;
    this.setupMessageHandler();
  }

  private setupMessageHandler(): void {
    this.unsubscribeMessages = this.connection.onMessage((message) => {
      this.handleMessage(message);
    });
  }

  private handleMessage(message: string): void {
    try {
      const json = JSON.parse(message);

      // Check if this is a notification (no id) or response (has id)
      if (!('id' in json)) {
        // It's a notification (event)
        this.handleNotification(json as NativeRPCNotification);
      } else {
        // It's a response
        this.handleResponse(json as NativeRPCResponse);
      }
    } catch (e) {
      this.log('Error handling message:', e);
    }
  }

  private handleResponse(response: NativeRPCResponse): void {
    const pending = this.pendingRequests.get(response.id);
    if (pending) {
      clearTimeout(pending.timeoutId);
      this.pendingRequests.delete(response.id);
      pending.resolve(response);
    }
  }

  private handleNotification(notification: NativeRPCNotification): void {
    // notification.method is "service.event" format
    const handlers = this.eventHandlers.get(notification.method);
    if (handlers) {
      for (const handler of handlers) {
        try {
          handler(notification.params);
        } catch (e) {
          this.log('Error in event handler:', e);
        }
      }
    }
  }

  /**
   * Call a method on a service
   *
   * @param method - Method in format "service.method"
   * @param params - Optional parameters
   * @returns The result data on success
   * @throws {NativeRPCError} on failure
   *
   * @example
   * ```typescript
   * const count = await client.call<number>('counter.increment', { step: 1 });
   * ```
   */
  async call<T = unknown>(method: string, params?: Record<string, unknown>): Promise<T> {
    this.checkDisposed();

    const request: NativeRPCRequest = {
      id: generateId(),
      method,
      ...(params !== undefined && { params }),
    };

    const requestStr = JSON.stringify(request);
    this.log('Sending request:', request);

    // Try synchronous response first (some bridges support it)
    const syncResponse = await this.connection.send(requestStr);

    if (syncResponse) {
      const response = JSON.parse(syncResponse) as NativeRPCResponse;
      this.log('Received sync response:', response);

      if (response.error) {
        throw NativeRPCError.fromErrorObject(response.error);
      }

      return response.result as T;
    }

    // Wait for async response
    return new Promise<T>((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.pendingRequests.delete(request.id);
        reject(NativeRPCError.timeout(`Method call ${method} timed out`));
      }, this.timeout);

      this.pendingRequests.set(request.id, {
        resolve: (response) => {
          this.log('Received async response:', response);

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
  }

  /**
   * Subscribe to an event
   *
   * @param event - Event in format "service.event"
   * @param handler - Callback for event data
   * @returns A subscription that can be cancelled
   *
   * @example
   * ```typescript
   * const sub = await client.subscribe('counter.countChanged', (data) => {
   *   console.log('Count:', data.count);
   * });
   *
   * // Later...
   * await sub.cancel();
   * ```
   */
  async subscribe<T = unknown>(event: string, handler: EventHandler<T>): Promise<NativeRPCEventSubscription> {
    this.checkDisposed();

    let handlers = this.eventHandlers.get(event);
    const isFirstSubscriber = !handlers || handlers.size === 0;

    if (!handlers) {
      handlers = new Set();
      this.eventHandlers.set(event, handlers);
    }
    handlers.add(handler as EventHandler);

    if (isFirstSubscriber) {
      const request = {
        id: generateId(),
        method: 'rpc.subscribe' as const,
        params: { event },
      };

      try {
        await this.connection.send(JSON.stringify(request));
        this.log('Subscribed to event:', event);
      } catch (e) {
        handlers.delete(handler as EventHandler);
        if (handlers.size === 0) {
          this.eventHandlers.delete(event);
        }
        throw e;
      }
    }

    return new NativeRPCEventSubscription(this, event, handler as EventHandler);
  }

  /**
   * Subscribe to an event and return an async iterator
   *
   * @param event - Event in format "service.event"
   * @returns An async iterable of event data
   *
   * @example
   * ```typescript
   * for await (const data of client.events('counter.countChanged')) {
   *   console.log('Count:', data.count);
   * }
   * ```
   */
  async *events<T = unknown>(event: string): AsyncGenerator<T, void, unknown> {
    const queue: T[] = [];
    let resolve: (() => void) | null = null;
    let cancelled = false;

    const handler = (data: T) => {
      queue.push(data);
      resolve?.();
    };

    const subscription = await this.subscribe(event, handler);

    try {
      while (!cancelled && !this.disposed) {
        if (queue.length > 0) {
          yield queue.shift()!;
        } else {
          await new Promise<void>((r) => {
            resolve = r;
          });
          resolve = null;
        }
      }
    } finally {
      cancelled = true;
      await subscription.cancel();
    }
  }

  /**
   * Internal method to unsubscribe from an event
   */
  private async unsubscribe(event: string, handler: EventHandler): Promise<void> {
    const handlers = this.eventHandlers.get(event);
    if (!handlers) return;

    handlers.delete(handler);

    if (handlers.size === 0) {
      this.eventHandlers.delete(event);

      if (!this.disposed) {
        const request = {
          id: generateId(),
          method: 'rpc.unsubscribe' as const,
          params: { event },
        };

        try {
          await this.connection.send(JSON.stringify(request));
          this.log('Unsubscribed from event:', event);
        } catch (e) {
          this.log('Error sending unsubscribe:', e);
        }
      }
    }
  }

  /**
   * Ping the native side to check connection
   */
  async ping(): Promise<boolean> {
    this.checkDisposed();
    return this.connection.ping();
  }

  /**
   * Check if the client is connected and active
   */
  get isConnected(): boolean {
    return !this.disposed && this.connection.isActive;
  }

  /**
   * Dispose the client and clean up resources
   */
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true;

    // Reject all pending requests
    for (const [id, pending] of this.pendingRequests) {
      clearTimeout(pending.timeoutId);
      pending.reject(NativeRPCError.connectionError('Client disposed'));
    }
    this.pendingRequests.clear();

    // Clear event handlers
    this.eventHandlers.clear();

    // Unsubscribe from messages
    this.unsubscribeMessages?.();
    this.unsubscribeMessages = null;

    // Close connection
    this.connection.close();
  }

  private checkDisposed(): void {
    if (this.disposed) {
      throw NativeRPCError.connectionError('Client has been disposed');
    }
  }

  private log(...args: unknown[]): void {
    if (this.debug) {
      console.log('[NativeRPC]', ...args);
    }
  }
}
