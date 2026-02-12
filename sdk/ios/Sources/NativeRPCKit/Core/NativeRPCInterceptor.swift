// NativeRPCInterceptor.swift
// NativeRPCKit
//
// Created by 吕良(吕游)
//
// Middleware system for intercepting RPC messages.
// Similar to Alamofire's RequestInterceptor pattern.

import Foundation

// MARK: - Interceptor Context

/// Context passed to interceptors containing request/response information
public struct NativeRPCInterceptorContext: Sendable {
    /// The connection ID (for correlation)
    public let connectionId: String
    
    /// The connection type
    public let connectionType: NativeRPCConnectionType
    
    /// Timestamp when the message was received/sent
    public let timestamp: Date
    
    /// Additional metadata (can be populated by interceptors)
    public var metadata: [String: any Sendable]
    
    public init(
        connectionId: String,
        connectionType: NativeRPCConnectionType,
        timestamp: Date = Date(),
        metadata: [String: any Sendable] = [:]
    ) {
        self.connectionId = connectionId
        self.connectionType = connectionType
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Request Info

/// Information about an incoming RPC request (for interceptors)
public struct NativeRPCRequestInfo: Sendable {
    /// The request ID
    public let id: String
    
    /// Full method name (service.method)
    public let method: String
    
    /// Service name
    public let service: String
    
    /// Method name (without service prefix)
    public let methodName: String
    
    /// Request type
    public let type: RequestType
    
    /// Raw parameters (as AnyCodable for Sendable)
    public let params: AnyCodable?
    
    /// Request types
    public enum RequestType: String, Sendable {
        case call
        case subscribe
        case unsubscribe
    }
    
    public init(
        id: String,
        method: String,
        service: String,
        methodName: String,
        type: RequestType,
        params: Any?
    ) {
        self.id = id
        self.method = method
        self.service = service
        self.methodName = methodName
        self.type = type
        self.params = params.map { AnyCodable($0) }
    }
}

// MARK: - Response Info

/// Information about an outgoing RPC response (for interceptors)
public struct NativeRPCResponseInfo: Sendable {
    /// The request ID this responds to
    public let id: String
    
    /// Whether the response is successful
    public let isSuccess: Bool
    
    /// Result data (for success)
    public let result: AnyCodable?
    
    /// Error info (for failure)
    public let error: ErrorInfo?
    
    /// Time taken to process the request (in seconds)
    public let duration: TimeInterval
    
    /// Error information
    public struct ErrorInfo: Sendable {
        public let code: Int
        public let message: String
        
        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }
    
    /// Create a success response info
    public static func success(id: String, result: Any?, duration: TimeInterval) -> NativeRPCResponseInfo {
        NativeRPCResponseInfo(
            id: id,
            isSuccess: true,
            result: result.map { AnyCodable($0) },
            error: nil,
            duration: duration
        )
    }
    
    /// Create an error response info
    public static func failure(id: String, error: NativeRPCError, duration: TimeInterval) -> NativeRPCResponseInfo {
        NativeRPCResponseInfo(
            id: id,
            isSuccess: false,
            result: nil,
            error: ErrorInfo(code: error.code, message: error.message),
            duration: duration
        )
    }
}

// MARK: - Event Info

/// Information about an outgoing event (for interceptors)
public struct NativeRPCEventInfo: Sendable {
    /// Full event name (service.event)
    public let event: String
    
    /// Service name
    public let service: String
    
    /// Event name (without service prefix)
    public let eventName: String
    
    /// Event data
    public let params: AnyCodable?
    
    public init(event: String, service: String, eventName: String, params: Any?) {
        self.event = event
        self.service = service
        self.eventName = eventName
        self.params = params.map { AnyCodable($0) }
    }
}

// MARK: - Outgoing Message Info

/// Information about any outgoing message (for interceptors)
public enum NativeRPCOutgoingMessage: Sendable {
    /// A response to a request
    case response(NativeRPCResponseInfo, request: NativeRPCRequestInfo)
    /// An event notification
    case event(NativeRPCEventInfo)
    
    /// Get a description for logging
    public var description: String {
        switch self {
        case .response(let response, let request):
            let status = response.isSuccess ? "✓" : "✗"
            return "response: \(request.method) \(status)"
        case .event(let event):
            return "event: \(event.event)"
        }
    }
}

// MARK: - Interceptor Protocol

/// Protocol for intercepting RPC messages.
///
/// Implement this protocol to create custom middleware for:
/// - Logging requests/responses
/// - Monitoring and metrics
/// - Request/response modification
/// - Error handling
/// - Authentication
///
/// Example:
/// ```swift
/// class LoggingInterceptor: NativeRPCInterceptor {
///     func willSendRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
///         print("→ \(request.method)")
///     }
///
///     func didReceiveResponse(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
///         let status = response.isSuccess ? "✓" : "✗"
///         print("← \(request.method) \(status) (\(response.duration)s)")
///     }
/// }
/// ```
public protocol NativeRPCInterceptor: AnyObject, Sendable {
    
    // MARK: - Request Interception
    
    /// Called before processing an incoming request.
    ///
    /// Use this to:
    /// - Log incoming requests
    /// - Validate requests
    /// - Start timing
    ///
    /// - Parameters:
    ///   - request: Information about the request
    ///   - context: The interceptor context
    func willProcessRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext)
    
    /// Called after processing a request, with the response.
    ///
    /// Use this to:
    /// - Log responses
    /// - Record metrics
    /// - Handle errors
    ///
    /// - Parameters:
    ///   - response: Information about the response
    ///   - request: The original request
    ///   - context: The interceptor context
    func didProcessRequest(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext)
    
    // MARK: - Event Interception
    
    /// Called before sending an event to the client.
    ///
    /// - Parameters:
    ///   - event: Information about the event
    ///   - context: The interceptor context
    func willSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext)
    
    /// Called after sending an event to the client.
    ///
    /// - Parameters:
    ///   - event: Information about the event
    ///   - context: The interceptor context
    func didSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext)
    
    // MARK: - Unified Message Interception
    
    /// Called before sending any outgoing message (response or event).
    ///
    /// This is a unified hook for all outgoing messages. Use this for:
    /// - Raw message logging
    /// - Message encryption
    /// - Network layer monitoring
    ///
    /// - Parameters:
    ///   - message: The outgoing message (response or event)
    ///   - context: The interceptor context
    func willSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext)
    
    /// Called after sending any outgoing message (response or event).
    ///
    /// - Parameters:
    ///   - message: The outgoing message (response or event)
    ///   - context: The interceptor context
    func didSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext)
    
    // MARK: - Lifecycle Interception
    
    /// Called when a connection is established.
    ///
    /// - Parameter context: The interceptor context
    func didConnect(context: NativeRPCInterceptorContext)
    
    /// Called when a connection is closed.
    ///
    /// - Parameter context: The interceptor context
    func didDisconnect(context: NativeRPCInterceptorContext)
    
    /// Called when a service instance is created.
    ///
    /// - Parameters:
    ///   - serviceName: The service name
    ///   - context: The interceptor context
    func didCreateService(_ serviceName: String, context: NativeRPCInterceptorContext)
    
    /// Called when a service instance is destroyed.
    ///
    /// - Parameters:
    ///   - serviceName: The service name
    ///   - context: The interceptor context
    func didDestroyService(_ serviceName: String, context: NativeRPCInterceptorContext)
}

// MARK: - Default Implementations

/// Default empty implementations - interceptors only need to implement methods they care about
public extension NativeRPCInterceptor {
    func willProcessRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {}
    func didProcessRequest(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {}
    func willSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {}
    func didSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {}
    func willSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext) {}
    func didSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext) {}
    func didConnect(context: NativeRPCInterceptorContext) {}
    func didDisconnect(context: NativeRPCInterceptorContext) {}
    func didCreateService(_ serviceName: String, context: NativeRPCInterceptorContext) {}
    func didDestroyService(_ serviceName: String, context: NativeRPCInterceptorContext) {}
}

// MARK: - Interceptor Chain

/// Manages a chain of interceptors
public final class NativeRPCInterceptorChain: @unchecked Sendable {
    
    /// The interceptors in the chain
    private var interceptors: [NativeRPCInterceptor] = []
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    public init() {}
    
    /// Add an interceptor to the chain
    public func add(_ interceptor: NativeRPCInterceptor) {
        lock.lock()
        defer { lock.unlock() }
        interceptors.append(interceptor)
    }
    
    /// Remove all interceptors
    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        interceptors.removeAll()
    }
    
    /// Get a snapshot of current interceptors
    private var currentInterceptors: [NativeRPCInterceptor] {
        lock.lock()
        defer { lock.unlock() }
        return interceptors
    }
    
    // MARK: - Dispatch Methods
    
    func willProcessRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.willProcessRequest(request, context: context)
        }
    }
    
    func didProcessRequest(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didProcessRequest(response, for: request, context: context)
        }
    }
    
    func willSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.willSendEvent(event, context: context)
        }
    }
    
    func didSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didSendEvent(event, context: context)
        }
    }
    
    func willSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.willSendMessage(message, context: context)
        }
    }
    
    func didSendMessage(_ message: NativeRPCOutgoingMessage, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didSendMessage(message, context: context)
        }
    }
    
    func didConnect(context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didConnect(context: context)
        }
    }
    
    func didDisconnect(context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didDisconnect(context: context)
        }
    }
    
    func didCreateService(_ serviceName: String, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didCreateService(serviceName, context: context)
        }
    }
    
    func didDestroyService(_ serviceName: String, context: NativeRPCInterceptorContext) {
        for interceptor in currentInterceptors {
            interceptor.didDestroyService(serviceName, context: context)
        }
    }
}

// MARK: - Logging Interceptor

/// A simple logging interceptor that prints RPC messages.
///
/// Example:
/// ```swift
/// // Add to service center for global logging
/// NativeRPCServiceCenter.shared.addInterceptor(NativeRPCLoggingInterceptor())
///
/// // Or configure with options
/// let logger = NativeRPCLoggingInterceptor(
///     logLevel: .verbose,
///     prefix: "[MyApp RPC]"
/// )
/// NativeRPCServiceCenter.shared.addInterceptor(logger)
/// ```
public final class NativeRPCLoggingInterceptor: NativeRPCInterceptor, @unchecked Sendable {
    
    /// Log level
    public enum LogLevel: Int, Sendable {
        case none = 0
        case error = 1
        case info = 2
        case verbose = 3
    }
    
    /// Current log level
    public var logLevel: LogLevel
    
    /// Log prefix
    public let prefix: String
    
    /// Custom log handler (defaults to print)
    public var logHandler: (@Sendable (String) -> Void)?
    
    public init(logLevel: LogLevel = .info, prefix: String = "[NativeRPC]") {
        self.logLevel = logLevel
        self.prefix = prefix
    }
    
    private func log(_ level: LogLevel, _ message: String) {
        guard level.rawValue <= logLevel.rawValue else { return }
        let fullMessage = "\(prefix) \(message)"
        if let handler = logHandler {
            handler(fullMessage)
        } else {
            print(fullMessage)
        }
    }
    
    // MARK: - NativeRPCInterceptor
    
    public func willProcessRequest(_ request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        switch request.type {
        case .call:
            log(.info, "→ \(request.method)")
            if logLevel == .verbose, let params = request.params {
                log(.verbose, "  params: \(params.value)")
            }
        case .subscribe:
            log(.verbose, "→ subscribe: \(request.method)")
        case .unsubscribe:
            log(.verbose, "→ unsubscribe: \(request.method)")
        }
    }
    
    public func didProcessRequest(_ response: NativeRPCResponseInfo, for request: NativeRPCRequestInfo, context: NativeRPCInterceptorContext) {
        let durationMs = String(format: "%.2f", response.duration * 1000)
        
        if response.isSuccess {
            log(.info, "← \(request.method) ✓ (\(durationMs)ms)")
            if logLevel == .verbose, let result = response.result {
                log(.verbose, "  result: \(result.value)")
            }
        } else if let error = response.error {
            log(.error, "← \(request.method) ✗ [\(error.code)] \(error.message) (\(durationMs)ms)")
        }
    }
    
    public func willSendEvent(_ event: NativeRPCEventInfo, context: NativeRPCInterceptorContext) {
        log(.info, "⇢ \(event.event)")
        if logLevel == .verbose, let params = event.params {
            log(.verbose, "  params: \(params.value)")
        }
    }
    
    public func didConnect(context: NativeRPCInterceptorContext) {
        log(.info, "Connection opened: \(context.connectionId) (\(context.connectionType.rawValue))")
    }
    
    public func didDisconnect(context: NativeRPCInterceptorContext) {
        log(.info, "Connection closed: \(context.connectionId)")
    }
    
    public func didCreateService(_ serviceName: String, context: NativeRPCInterceptorContext) {
        log(.verbose, "Created service: \(serviceName)")
    }
    
    public func didDestroyService(_ serviceName: String, context: NativeRPCInterceptorContext) {
        log(.verbose, "Destroyed service: \(serviceName)")
    }
}
