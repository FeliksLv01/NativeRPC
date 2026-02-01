// NativeRPCError.kt
// NativeRPC v2
//
// Error types for the simplified JSON-RPC 2.0 protocol
//
// Error format: {"code": -32601, "message": "Method not found", "data": {...}}

package com.itoken.team.nativerpc.core

import kotlinx.serialization.json.JsonElement

// MARK: - Error Codes (JSON-RPC 2.0 Standard)

/**
 * JSON-RPC 2.0 standard error codes
 */
object NativeRPCErrorCode {
    /** Parse error - Invalid JSON was received */
    const val PARSE_ERROR = -32700
    
    /** Invalid Request - The JSON sent is not a valid Request object */
    const val INVALID_REQUEST = -32600
    
    /** Method not found - The method does not exist / is not available */
    const val METHOD_NOT_FOUND = -32601
    
    /** Invalid params - Invalid method parameter(s) */
    const val INVALID_PARAMS = -32602
    
    /** Internal error - Internal JSON-RPC error */
    const val INTERNAL_ERROR = -32603
    
    /** Server error range: -32000 to -32099 (reserved for implementation-defined server-errors) */
    const val SERVER_ERROR_START = -32000
    const val SERVER_ERROR_END = -32099
    
    // Custom error codes (within server error range)
    const val SERVICE_NOT_FOUND = -32001
    const val EVENT_NOT_FOUND = -32002
    const val EVENT_NOT_DECLARED = -32003
    const val TIMEOUT = -32004
    const val CONNECTION_ERROR = -32005
    const val CONNECTION_TYPE_NOT_SUPPORTED = -32006
}

// MARK: - Error Type

/**
 * RPC error that can be sent to clients
 *
 * Format: {"code": -32601, "message": "Method not found", "data": {...}}
 */
open class NativeRPCError(
    /** Numeric error code (negative for standard/server errors) */
    val code: Int,
    /** Human-readable error message */
    override val message: String,
    /** Optional additional error data */
    val data: JsonElement? = null
) : Exception(message) {
    
    /** Check if this is a standard JSON-RPC error */
    val isStandardError: Boolean
        get() = code in -32700..-32600
    
    /** Check if this is a server error (within -32000 to -32099 range) */
    val isServerError: Boolean
        get() = code in -32099..-32000
    
    companion object {
        // MARK: - Predefined Errors
        
        /** Parse error - Invalid JSON was received */
        fun parseError(message: String? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.PARSE_ERROR,
                message ?: "Parse error"
            )
        }
        
        /** Invalid Request - The JSON sent is not a valid Request object */
        fun invalidRequest(message: String? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.INVALID_REQUEST,
                message ?: "Invalid request"
            )
        }
        
        /** Method not found */
        fun methodNotFound(method: String, service: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.METHOD_NOT_FOUND,
                "Method '$method' not found in service '$service'"
            )
        }
        
        /** Method not found (simple version) */
        fun methodNotFound(message: String? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.METHOD_NOT_FOUND,
                message ?: "Method not found"
            )
        }
        
        /** Invalid params - Invalid method parameter(s) */
        fun invalidParams(message: String? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.INVALID_PARAMS,
                message ?: "Invalid params"
            )
        }
        
        /** Invalid arguments (alias for invalidParams) */
        fun invalidArguments(message: String? = null): NativeRPCError {
            return invalidParams(message)
        }
        
        /** Internal error */
        fun internalError(message: String? = null, data: JsonElement? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.INTERNAL_ERROR,
                message ?: "Internal error",
                data
            )
        }
        
        /** Service not found */
        fun serviceNotFound(service: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.SERVICE_NOT_FOUND,
                "Service '$service' not found"
            )
        }
        
        /** Event not found in service */
        fun eventNotFound(event: String, service: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.EVENT_NOT_FOUND,
                "Event '$event' not found in service '$service'"
            )
        }
        
        /** Event not declared in service definition */
        fun eventNotDeclared(event: String, service: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.EVENT_NOT_DECLARED,
                "Event '$event' not declared in service '$service'. Add it to Events() in your service definition."
            )
        }
        
        /** Timeout error */
        fun timeout(message: String? = null): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.TIMEOUT,
                message ?: "Request timed out"
            )
        }
        
        /** Connection error */
        fun connectionError(message: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.CONNECTION_ERROR,
                message
            )
        }
        
        /** Connection type not supported by service */
        fun connectionTypeNotSupported(service: String, connectionType: String): NativeRPCError {
            return NativeRPCError(
                NativeRPCErrorCode.CONNECTION_TYPE_NOT_SUPPORTED,
                "Service '$service' does not support connection type '$connectionType'"
            )
        }
        
        /** Custom error with user-defined code */
        fun custom(code: Int, message: String, data: JsonElement? = null): NativeRPCError {
            return NativeRPCError(code, message, data)
        }
    }
}
