// types.ts
// NativeRPC Web Connection
//
// Core type definitions for the simplified JSON-RPC 2.0 protocol

/**
 * JSON-RPC Request
 * Format: {"id": "uuid", "method": "service.method", "params": {...}, "frameId": "..."}
 */
export interface NativeRPCRequest {
  id: string;
  method: string;
  params?: Record<string, unknown> | unknown[];
  /** Unique identifier for the frame/window that sent this request (for iframe support) */
  frameId?: string;
}

/**
 * JSON-RPC Response (success)
 * Format: {"id": "uuid", "result": ..., "frameId": "..."}
 */
export interface NativeRPCResponse {
  id: string;
  result?: unknown;
  error?: NativeRPCErrorObject;
  /** Frame ID to route response back to (for iframe support) */
  frameId?: string;
}

/**
 * JSON-RPC Error object
 * Format: {"code": -32601, "message": "Method not found", "data": {...}}
 */
export interface NativeRPCErrorObject {
  code: number;
  message: string;
  data?: unknown;
}

/**
 * JSON-RPC Notification (event from server, no id)
 * Format: {"method": "service.event", "params": {...}, "frameId": "..."}
 */
export interface NativeRPCNotification {
  method: string;
  params?: unknown;
  /** Frame ID to route event to (for iframe support) */
  frameId?: string;
}

/**
 * Subscribe request
 * Format: {"id": "uuid", "method": "rpc.subscribe", "params": {"event": "service.event"}}
 */
export interface NativeRPCSubscribeRequest {
  id: string;
  method: 'rpc.subscribe';
  params: { event: string };
}

/**
 * Unsubscribe request
 * Format: {"id": "uuid", "method": "rpc.unsubscribe", "params": {"event": "service.event"}}
 */
export interface NativeRPCUnsubscribeRequest {
  id: string;
  method: 'rpc.unsubscribe';
  params: { event: string };
}

/**
 * Message that can be sent to native
 */
export type OutgoingMessage = NativeRPCRequest | NativeRPCSubscribeRequest | NativeRPCUnsubscribeRequest;

/**
 * Message that can be received from native
 */
export type IncomingMessage = NativeRPCResponse | NativeRPCNotification;

/**
 * JSON-RPC 2.0 standard error codes
 */
export const NativeRPCErrorCode = {
  /** Parse error - Invalid JSON was received */
  parseError: -32700,
  /** Invalid Request - The JSON sent is not a valid Request object */
  invalidRequest: -32600,
  /** Method not found - The method does not exist / is not available */
  methodNotFound: -32601,
  /** Invalid params - Invalid method parameter(s) */
  invalidParams: -32602,
  /** Internal error - Internal JSON-RPC error */
  internalError: -32603,

  // Custom error codes (within server error range -32000 to -32099)
  serviceNotFound: -32001,
  eventNotFound: -32002,
  timeout: -32003,
  connectionError: -32004,
} as const;

export type NativeRPCErrorCodeType = (typeof NativeRPCErrorCode)[keyof typeof NativeRPCErrorCode];

/**
 * Event handler callback type
 */
export type EventHandler<T = unknown> = (data: T) => void;

/**
 * Connection interface - implemented by different transport layers
 */
export interface NativeRPCConnection {
  /** Unique identifier for this connection */
  readonly id: string;

  /** Whether the connection is active */
  readonly isActive: boolean;

  /**
   * Send a message to native
   * @param message - JSON string to send
   * @returns Response JSON string (for sync transports) or null
   */
  send(message: string): Promise<string | null>;

  /**
   * Register a callback for incoming messages (responses and events)
   * @param handler - Callback for incoming JSON messages
   * @returns Unsubscribe function
   */
  onMessage(handler: (message: string) => void): () => void;

  /** Close the connection */
  close(): void;

  /** Ping the native side to check connection */
  ping(): Promise<boolean>;
}
