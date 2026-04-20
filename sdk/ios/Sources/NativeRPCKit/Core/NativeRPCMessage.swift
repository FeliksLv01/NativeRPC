// NativeRPCMessage.swift
// NativeRPC v2
//
// Core message types for the simplified JSON-RPC 2.0 protocol (without jsonrpc field)
//
// Request:      {"id": "1", "method": "service.method", "params": {...}}
// Response:     {"id": "1", "result": ...}
// Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
// Notification: {"method": "service.event", "params": {...}}  (no id)

import Foundation

// MARK: - Incoming Message Parsing

/// Helper to determine message type from raw JSON
public enum NativeRPCMessageParser {
    
    /// Parse a raw JSON message and determine its type
    public static func parse(_ data: Data) throws -> NativeRPCIncomingMessage {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else {
            throw NativeRPCError.parseError("Invalid JSON")
        }
        
        // Check if it has an id (request) or not (notification)
        guard let id = json["id"] as? String else {
            throw NativeRPCError.invalidRequest("Missing id in request")
        }
        
        guard let method = json["method"] as? String else {
            throw NativeRPCError.invalidRequest("Missing method in request")
        }
        
        let params = json["params"]
        
        // Check for special RPC methods
        if method == "rpc.subscribe" {
            guard let paramsDict = params as? [String: Any],
                  let event = paramsDict["event"] as? String else {
                throw NativeRPCError.invalidParams("rpc.subscribe requires params.event")
            }
            let subscribeParams = paramsDict["params"] as? [String: Any]
            return .subscribe(NativeRPCSubscribeRequest(id: id, event: event, params: subscribeParams))
        }
        
        if method == "rpc.unsubscribe" {
            guard let paramsDict = params as? [String: Any],
                  let event = paramsDict["event"] as? String else {
                throw NativeRPCError.invalidParams("rpc.unsubscribe requires params.event")
            }
            return .unsubscribe(NativeRPCUnsubscribeRequest(id: id, event: event))
        }
        
        // Regular method call
        return .call(NativeRPCRequest(id: id, method: method, params: params))
    }
}

/// Represents an incoming message that has been parsed
public enum NativeRPCIncomingMessage {
    case call(NativeRPCRequest)
    case subscribe(NativeRPCSubscribeRequest)
    case unsubscribe(NativeRPCUnsubscribeRequest)
}

// MARK: - Request

/// A JSON-RPC request from client to native
///
/// Format: {"id": "uuid", "method": "service.method", "params": {...}}
public struct NativeRPCRequest {
    /// Unique request identifier
    public let id: String
    
    /// Method in format "service.method"
    public let method: String
    
    /// Optional parameters
    public let params: Any?
    
    /// Get service name from method
    public var service: String {
        let parts = method.split(separator: ".")
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: ".")
        }
        return method
    }
    
    /// Get method name from method
    public var methodName: String {
        let parts = method.split(separator: ".")
        return parts.last.map(String.init) ?? method
    }
    
    /// Get params as dictionary
    public var paramsDict: [String: Any]? {
        return params as? [String: Any]
    }
    
    public init(id: String = UUID().uuidString, method: String, params: Any? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
    
    /// Create a request from separate service and method names
    public init(id: String = UUID().uuidString, service: String, methodName: String, params: Any? = nil) {
        self.id = id
        self.method = "\(service).\(methodName)"
        self.params = params
    }
}

// MARK: - Response

/// A JSON-RPC success response
///
/// Format: {"id": "uuid", "result": ...}
public struct NativeRPCResponse: Encodable {
    /// Request identifier this is responding to
    public let id: String
    
    /// Result data
    public let result: RPCAnyCodable?
    
    public init(id: String, result: Any?) {
        self.id = id
        self.result = result.map { RPCAnyCodable($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, result
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        // Always encode result, even if nil (as null)
        try container.encode(result, forKey: .result)
    }
}

// MARK: - Error Response

/// A JSON-RPC error response
///
/// Format: {"id": "uuid", "error": {"code": -32601, "message": "...", "data": ...}}
public struct NativeRPCErrorResponse: Encodable {
    /// Request identifier this is responding to
    public let id: String
    
    /// Error information
    public let error: NativeRPCErrorInfo
    
    public init(id: String, error: NativeRPCError) {
        self.id = id
        self.error = NativeRPCErrorInfo(from: error)
    }
}

/// Error information object within error response
///
/// Format: {"code": -32601, "message": "Method not found", "data": {...}}
public struct NativeRPCErrorInfo: Encodable {
    /// Numeric error code (negative for standard/server errors)
    public let code: Int
    
    /// Human-readable error message
    public let message: String
    
    /// Optional additional error data
    public var data: RPCAnyCodable?
    
    public init(from error: NativeRPCError) {
        self.code = error.code
        self.message = error.message
        self.data = error.data.map { RPCAnyCodable($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case code, message, data
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        if let data = data {
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Notification (Event)

/// A JSON-RPC notification from native to client (no id = no response expected)
///
/// Format: {"method": "service.event", "params": {...}}
public struct NativeRPCNotification: Encodable, Sendable {
    /// Method/event in format "service.event"
    public let method: String
    
    /// Event data
    public let params: RPCAnyCodable?
    
    public init(service: String, event: String, params: Any? = nil) {
        self.method = "\(service).\(event)"
        self.params = params.map { RPCAnyCodable($0) }
    }
    
    public init(method: String, params: Any? = nil) {
        self.method = method
        self.params = params.map { RPCAnyCodable($0) }
    }
    
    enum CodingKeys: String, CodingKey {
        case method, params
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        if let params = params {
            try container.encode(params, forKey: .params)
        }
    }
}

// MARK: - Subscribe/Unsubscribe Requests

/// A subscribe request
///
/// Format: {"id": "uuid", "method": "rpc.subscribe", "params": {"event": "service.event", "params": {...}}}
public struct NativeRPCSubscribeRequest: @unchecked Sendable {
    public let id: String
    public let event: String
    /// Optional parameters passed with the subscription (e.g., topics for socketMessage)
    public let params: [String: Any]?
    
    /// Get service name from event
    public var service: String {
        let parts = event.split(separator: ".")
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: ".")
        }
        return event
    }
    
    /// Get event name from event
    public var eventName: String {
        let parts = event.split(separator: ".")
        return parts.last.map(String.init) ?? event
    }
    
    public init(id: String = UUID().uuidString, event: String, params: [String: Any]? = nil) {
        self.id = id
        self.event = event
        self.params = params
    }
}

/// An unsubscribe request
///
/// Format: {"id": "uuid", "method": "rpc.unsubscribe", "params": {"event": "service.event"}}
public struct NativeRPCUnsubscribeRequest: Sendable {
    public let id: String
    public let event: String
    
    /// Get service name from event
    public var service: String {
        let parts = event.split(separator: ".")
        if parts.count >= 2 {
            return parts.dropLast().joined(separator: ".")
        }
        return event
    }
    
    /// Get event name from event
    public var eventName: String {
        let parts = event.split(separator: ".")
        return parts.last.map(String.init) ?? event
    }
    
    public init(id: String = UUID().uuidString, event: String) {
        self.id = id
        self.event = event
    }
}

// MARK: - Legacy Compatibility (to be removed)

/// Legacy event type (for backward compatibility during migration)
@available(*, deprecated, message: "Use NativeRPCNotification instead")
public typealias NativeRPCEvent = NativeRPCNotification
