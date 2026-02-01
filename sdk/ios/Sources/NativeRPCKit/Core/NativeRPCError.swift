// NativeRPCError.swift
// NativeRPC v2
//
// Error types for the simplified JSON-RPC 2.0 protocol
//
// Error format: {"code": -32601, "message": "Method not found", "data": {...}}

import Foundation

// MARK: - Error Codes (JSON-RPC 2.0 Standard)

/// JSON-RPC 2.0 standard error codes
public struct NativeRPCErrorCode {
    /// Parse error - Invalid JSON was received
    public static let parseError = -32700
    
    /// Invalid Request - The JSON sent is not a valid Request object
    public static let invalidRequest = -32600
    
    /// Method not found - The method does not exist / is not available
    public static let methodNotFound = -32601
    
    /// Invalid params - Invalid method parameter(s)
    public static let invalidParams = -32602
    
    /// Internal error - Internal JSON-RPC error
    public static let internalError = -32603
    
    /// Server error range: -32000 to -32099 (reserved for implementation-defined server-errors)
    public static let serverErrorStart = -32000
    public static let serverErrorEnd = -32099
    
    // Custom error codes (within server error range)
    public static let serviceNotFound = -32001
    public static let eventNotFound = -32002
    public static let eventNotDeclared = -32003
    public static let timeout = -32004
    public static let connectionError = -32005
    public static let connectionTypeNotSupported = -32006
}

// MARK: - Error Type

/// RPC error that can be sent to clients
///
/// Format: {"code": -32601, "message": "Method not found", "data": {...}}
///
/// Note: Marked `@unchecked Sendable` because `data` is `Any?`.
/// Safety invariant: `data` should only contain JSON-serializable values
/// (String, Int, Double, Bool, Array, Dictionary) which are all value types.
public struct NativeRPCError: Error, @unchecked Sendable {
    /// Numeric error code (negative for standard/server errors)
    public let code: Int
    
    /// Human-readable error message
    public let message: String
    
    /// Optional additional error data
    public var data: Any?
    
    public init(code: Int, message: String, data: Any? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

// MARK: - Predefined Errors

extension NativeRPCError {
    /// Parse error - Invalid JSON was received
    public static func parseError(_ message: String? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.parseError,
            message: message ?? "Parse error"
        )
    }
    
    /// Invalid Request - The JSON sent is not a valid Request object
    public static func invalidRequest(_ message: String? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.invalidRequest,
            message: message ?? "Invalid request"
        )
    }
    
    /// Method not found
    public static func methodNotFound(_ method: String, service: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.methodNotFound,
            message: "Method '\(method)' not found in service '\(service)'"
        )
    }
    
    /// Method not found (simple version)
    public static func methodNotFound(_ message: String? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.methodNotFound,
            message: message ?? "Method not found"
        )
    }
    
    /// Invalid params - Invalid method parameter(s)
    public static func invalidParams(_ message: String? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.invalidParams,
            message: message ?? "Invalid params"
        )
    }
    
    /// Invalid arguments (alias for invalidParams)
    public static func invalidArguments(_ message: String? = nil) -> NativeRPCError {
        invalidParams(message)
    }
    
    /// Internal error
    public static func internalError(_ message: String? = nil, data: Any? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.internalError,
            message: message ?? "Internal error",
            data: data
        )
    }
    
    /// Service not found
    public static func serviceNotFound(_ service: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.serviceNotFound,
            message: "Service '\(service)' not found"
        )
    }
    
    /// Event not found in service
    public static func eventNotFound(_ event: String, service: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.eventNotFound,
            message: "Event '\(event)' not found in service '\(service)'"
        )
    }
    
    /// Event not declared in service definition
    public static func eventNotDeclared(_ event: String, service: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.eventNotDeclared,
            message: "Event '\(event)' not declared in service '\(service)'. Add it to Events() in your service definition."
        )
    }
    
    /// Timeout error
    public static func timeout(_ message: String? = nil) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.timeout,
            message: message ?? "Request timed out"
        )
    }
    
    /// Connection error
    public static func connectionError(_ message: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.connectionError,
            message: message
        )
    }
    
    /// Connection type not supported by service
    public static func connectionTypeNotSupported(service: String, connectionType: String) -> NativeRPCError {
        NativeRPCError(
            code: NativeRPCErrorCode.connectionTypeNotSupported,
            message: "Service '\(service)' does not support connection type '\(connectionType)'"
        )
    }
    
    /// Custom error with user-defined code
    public static func custom(code: Int, message: String, data: Any? = nil) -> NativeRPCError {
        NativeRPCError(code: code, message: message, data: data)
    }
}

// MARK: - LocalizedError

extension NativeRPCError: LocalizedError {
    public var errorDescription: String? {
        return "[\(code)] \(message)"
    }
}

// MARK: - Helper Properties

extension NativeRPCError {
    /// Check if this is a standard JSON-RPC error
    public var isStandardError: Bool {
        return code <= -32600 && code >= -32700
    }
    
    /// Check if this is a server error (within -32000 to -32099 range)
    public var isServerError: Bool {
        return code <= NativeRPCErrorCode.serverErrorStart && code >= NativeRPCErrorCode.serverErrorEnd
    }
}
