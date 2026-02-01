// NativeRPCError.kt
// NativeRPC v2
//
// Error types for NativeRPC

package com.itoken.team.nativerpc.core

import kotlinx.serialization.json.JsonElement

/**
 * Represents an error in the NativeRPC system
 */
open class NativeRPCError(
    val code: String,
    override val message: String,
    val details: JsonElement? = null
) : Exception(message) {
    
    companion object {
        // Error codes
        const val PARSE_ERROR = "PARSE_ERROR"
        const val INVALID_REQUEST = "INVALID_REQUEST"
        const val SERVICE_NOT_FOUND = "SERVICE_NOT_FOUND"
        const val METHOD_NOT_FOUND = "METHOD_NOT_FOUND"
        const val INVALID_ARGUMENTS = "INVALID_ARGUMENTS"
        const val INTERNAL_ERROR = "INTERNAL_ERROR"
        const val EVENT_NOT_DECLARED = "EVENT_NOT_DECLARED"
        const val CONNECTION_ERROR = "CONNECTION_ERROR"
        const val TIMEOUT = "TIMEOUT"
        
        // Factory methods
        fun parseError(details: String): NativeRPCError {
            return NativeRPCError(PARSE_ERROR, "Failed to parse message: $details")
        }
        
        fun invalidRequest(details: String): NativeRPCError {
            return NativeRPCError(INVALID_REQUEST, "Invalid request: $details")
        }
        
        fun serviceNotFound(serviceName: String): NativeRPCError {
            return NativeRPCError(SERVICE_NOT_FOUND, "Service not found: $serviceName")
        }
        
        fun methodNotFound(methodName: String, serviceName: String): NativeRPCError {
            return NativeRPCError(METHOD_NOT_FOUND, "Method '$methodName' not found in service '$serviceName'")
        }
        
        fun invalidArguments(details: String): NativeRPCError {
            return NativeRPCError(INVALID_ARGUMENTS, "Invalid arguments: $details")
        }
        
        fun internalError(details: String): NativeRPCError {
            return NativeRPCError(INTERNAL_ERROR, "Internal error: $details")
        }
        
        fun eventNotDeclared(eventName: String, serviceName: String): NativeRPCError {
            return NativeRPCError(EVENT_NOT_DECLARED, "Event '$eventName' not declared in service '$serviceName'")
        }
        
        fun connectionError(details: String): NativeRPCError {
            return NativeRPCError(CONNECTION_ERROR, "Connection error: $details")
        }
        
        fun timeout(details: String): NativeRPCError {
            return NativeRPCError(TIMEOUT, "Operation timed out: $details")
        }
    }
}
