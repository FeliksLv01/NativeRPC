// NativeRPCMessage.kt
// NativeRPC v2
//
// Core message types for the simplified JSON-RPC 2.0 protocol (without jsonrpc field)
//
// Request:      {"id": "1", "method": "service.method", "params": {...}}
// Response:     {"id": "1", "result": ...}
// Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
// Notification: {"method": "service.event", "params": {...}}  (no id)

package com.itoken.team.nativerpc.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import java.util.UUID

// MARK: - Request

/**
 * A JSON-RPC request from client to native
 *
 * Format: {"id": "uuid", "method": "service.method", "params": {...}}
 */
@Serializable
data class NativeRPCRequest(
    /** Unique request identifier */
    val id: String = UUID.randomUUID().toString(),
    /** Method in format "service.method" */
    val method: String,
    /** Optional parameters (can be object or array) */
    val params: JsonElement? = null
) {
    /** Get service name from method */
    val service: String
        get() {
            val parts = method.split(".")
            return if (parts.size >= 2) {
                parts.dropLast(1).joinToString(".")
            } else {
                method
            }
        }
    
    /** Get method name from method */
    val methodName: String
        get() {
            val parts = method.split(".")
            return parts.lastOrNull() ?: method
        }
    
    companion object {
        /** Create a request from separate service and method names */
        fun create(
            id: String = UUID.randomUUID().toString(),
            service: String,
            methodName: String,
            params: JsonElement? = null
        ): NativeRPCRequest {
            return NativeRPCRequest(
                id = id,
                method = "$service.$methodName",
                params = params
            )
        }
    }
}

// MARK: - Response

/**
 * A JSON-RPC success response
 *
 * Format: {"id": "uuid", "result": ...}
 */
@Serializable
data class NativeRPCResponse(
    /** Request identifier this is responding to */
    val id: String,
    /** Result data */
    val result: JsonElement? = null
) {
    companion object {
        fun success(id: String, result: JsonElement?): NativeRPCResponse {
            return NativeRPCResponse(id = id, result = result)
        }
    }
}

// MARK: - Error Response

/**
 * A JSON-RPC error response
 *
 * Format: {"id": "uuid", "error": {"code": -32601, "message": "...", "data": ...}}
 */
@Serializable
data class NativeRPCErrorResponse(
    /** Request identifier this is responding to */
    val id: String,
    /** Error information */
    val error: NativeRPCErrorInfo
) {
    companion object {
        fun from(id: String, error: NativeRPCError): NativeRPCErrorResponse {
            return NativeRPCErrorResponse(
                id = id,
                error = NativeRPCErrorInfo.from(error)
            )
        }
    }
}

/**
 * Error information object within error response
 *
 * Format: {"code": -32601, "message": "Method not found", "data": {...}}
 */
@Serializable
data class NativeRPCErrorInfo(
    /** Numeric error code (negative for standard/server errors) */
    val code: Int,
    /** Human-readable error message */
    val message: String,
    /** Optional additional error data */
    val data: JsonElement? = null
) {
    companion object {
        fun from(error: NativeRPCError): NativeRPCErrorInfo {
            return NativeRPCErrorInfo(
                code = error.code,
                message = error.message,
                data = error.data
            )
        }
    }
}

// MARK: - Notification (Event)

/**
 * A JSON-RPC notification from native to client (no id = no response expected)
 *
 * Format: {"method": "service.event", "params": {...}}
 */
@Serializable
data class NativeRPCNotification(
    /** Method/event in format "service.event" */
    val method: String,
    /** Event data */
    val params: JsonElement? = null
) {
    companion object {
        fun create(service: String, event: String, params: JsonElement? = null): NativeRPCNotification {
            return NativeRPCNotification(
                method = "$service.$event",
                params = params
            )
        }
    }
}

// MARK: - Subscribe/Unsubscribe Requests

/**
 * A subscribe request (parsed from standard request format)
 *
 * Original format: {"id": "uuid", "method": "rpc.subscribe", "params": {"event": "service.event"}}
 */
data class NativeRPCSubscribeRequest(
    val id: String,
    val event: String
) {
    /** Get service name from event */
    val service: String
        get() {
            val parts = event.split(".")
            return if (parts.size >= 2) {
                parts.dropLast(1).joinToString(".")
            } else {
                event
            }
        }
    
    /** Get event name from event */
    val eventName: String
        get() {
            val parts = event.split(".")
            return parts.lastOrNull() ?: event
        }
}

/**
 * An unsubscribe request (parsed from standard request format)
 *
 * Original format: {"id": "uuid", "method": "rpc.unsubscribe", "params": {"event": "service.event"}}
 */
data class NativeRPCUnsubscribeRequest(
    val id: String,
    val event: String
) {
    /** Get service name from event */
    val service: String
        get() {
            val parts = event.split(".")
            return if (parts.size >= 2) {
                parts.dropLast(1).joinToString(".")
            } else {
                event
            }
        }
    
    /** Get event name from event */
    val eventName: String
        get() {
            val parts = event.split(".")
            return parts.lastOrNull() ?: event
        }
}

// MARK: - Incoming Message Parsing

/**
 * Represents an incoming message that has been parsed
 */
sealed class NativeRPCIncomingMessage {
    data class Call(val request: NativeRPCRequest) : NativeRPCIncomingMessage()
    data class Subscribe(val request: NativeRPCSubscribeRequest) : NativeRPCIncomingMessage()
    data class Unsubscribe(val request: NativeRPCUnsubscribeRequest) : NativeRPCIncomingMessage()
}

// MARK: - Legacy Compatibility (to be removed)

/** Legacy event type (for backward compatibility during migration) */
@Deprecated("Use NativeRPCNotification instead", ReplaceWith("NativeRPCNotification"))
typealias NativeRPCEvent = NativeRPCNotification
