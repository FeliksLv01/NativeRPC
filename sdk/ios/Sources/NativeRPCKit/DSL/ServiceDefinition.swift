// ServiceDefinition.swift
// NativeRPC v2
//
// DSL definitions and service definition container

import Foundation

// MARK: - (Removed UnsafeSendableBox - no longer needed in v2.3+)

// MARK: - VoidParams

/// Placeholder type for functions with no parameters
/// Used internally to satisfy Decodable constraint when no params are needed
public struct VoidParams: Codable, Sendable {
    public init() {}
}

/// Placeholder type for functions that return nothing
/// Used internally to satisfy Encodable constraint when no result is returned
public struct VoidResult: Codable, Sendable {
    public init() {}
}

// MARK: - Base Protocols

/// Base marker protocol for all definition types
public protocol AnyDefinition {}

/// Marker protocol for definitions that can be used in service definition
public protocol AnyServiceDefinitionElement: AnyDefinition {}

// MARK: - Function Protocols

/// Type-erased protocol for sync functions
public protocol AnySyncFunction: AnyServiceDefinitionElement {
    var name: String { get }
    var argumentsCount: Int { get }
    /// Whether to run on MainActor (default: true for UI safety)
    var requiresMainActor: Bool { get }
    func call(args: [Any]) throws -> Any?
}

/// Type-erased protocol for async functions
public protocol AnyAsyncFunction: AnyServiceDefinitionElement {
    var name: String { get }
    var argumentsCount: Int { get }
    var queue: DispatchQueue? { get }
    var requiresMainActor: Bool { get }
    func call(args: [Any]) async throws -> Any?
}

// MARK: - Sync Function Definition

/// Synchronous function definition with Codable params support
///
/// By default, sync functions run on the main thread for UI safety.
/// Use `.runInBackground()` to explicitly run on a background queue.
public final class SyncFunctionDefinition<Params: Decodable, R: Encodable>: AnySyncFunction {
    public let name: String
    public let argumentsCount: Int
    private let body: (Params) throws -> R
    
    /// Whether to run on MainActor (default: true for UI safety)
    public private(set) var requiresMainActor: Bool = true
    
    public init(name: String, argumentsCount: Int, body: @escaping (Params) throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) throws -> Any? {
        let params: Params = try decodeParams(from: args)
        let result = try body(params)
        return try encodeResult(result)
    }
    
    private func decodeParams(from args: [Any]) throws -> Params {
        // VoidParams special handling - no params needed
        if Params.self == VoidParams.self {
            return VoidParams() as! Params
        }
        
        // Extract dictionary from args
        guard let dict = args.first as? [String: Any] else {
            throw NativeRPCError.invalidParams("Expected params dictionary, got: \(type(of: args.first ?? "nil"))")
        }
        
        // Use JSONDecoder to decode
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Params.self, from: data)
        } catch let error as DecodingError {
            throw NativeRPCError.invalidParams(describeDecodingError(error))
        }
    }
    
    private func encodeResult(_ result: R) throws -> Any {
        // For VoidResult, return nil
        if R.self == VoidResult.self {
            return NSNull()
        }
        
        // For basic types, return directly (they are already JSON-compatible)
        if result is Int || result is Double || result is String || result is Bool {
            return result
        }
        
        // For arrays and dictionaries of basic types, return directly
        if result is [Any] || result is [String: Any] {
            return result
        }
        
        // For complex Encodable types, encode to JSON-compatible dictionary/array
        let data = try JSONEncoder().encode(result)
        return try JSONSerialization.jsonObject(with: data)
    }
    
    // MARK: - Fluent API
    
    /// Run on a background queue instead of main thread.
    /// Use this for CPU-intensive operations that don't touch UI.
    @discardableResult
    public func runInBackground() -> Self {
        self.requiresMainActor = false
        return self
    }
}

// MARK: - Async Function Definition (Swift Concurrency)

/// Asynchronous function definition with Codable params support
/// Supports Swift async/await
///
/// Note: Marked `@unchecked Sendable` because the `body` closure is captured
/// and may be called from different isolation contexts.
/// Safety invariant: Callers ensure arguments/results are safe to pass across boundaries.
///
/// **Threading**: By default, async functions run on the main thread (MainActor) for UI safety,
/// consistent with `SyncFunctionDefinition`. The `@MainActor` isolation is baked into the
/// stored closure at init time, so calling the body from any context will automatically
/// dispatch to MainActor.
///
/// Use `init(name:argumentsCount:backgroundBody:)` or `BackgroundAsyncFunction()` DSL
/// to create functions that run on the cooperative thread pool instead.
public final class AsyncFunctionDefinition<Params: Decodable, R: Encodable & Sendable>: AnyAsyncFunction, @unchecked Sendable {
    public let name: String
    public let argumentsCount: Int
    
    /// The body closure — MainActor dispatch is baked in for MainActor bodies.
    /// For background bodies, this is the raw closure without actor isolation.
    private let body: (Params) async throws -> R
    
    /// Queue (always nil in v2.3+, kept for protocol compatibility)
    public var queue: DispatchQueue? { nil }
    
    /// Whether this function runs on MainActor
    public let requiresMainActor: Bool
    
    /// Create a MainActor-isolated async function (default).
    ///
    /// The body closure is guaranteed to run entirely on MainActor, including
    /// after any `await` suspension points within the closure.
    ///
    /// - Parameters:
    ///   - name: The function name
    ///   - argumentsCount: Number of arguments (0 or 1)
    ///   - body: The `@MainActor` async closure to execute
    public init(name: String, argumentsCount: Int, body: @MainActor @escaping (Params) async throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.requiresMainActor = true
        // Wrap the @MainActor closure in a non-isolated wrapper.
        // When this wrapper calls the captured @MainActor closure,
        // Swift will automatically dispatch to MainActor — this is guaranteed
        // by Swift's actor isolation model.
        //
        // Note: Swift 6 may warn about non-Sendable Params/R crossing isolation
        // boundaries. This is safe because Params are decoded from JSON (value-like)
        // and results are encoded back to JSON before leaving this context.
        // Use nonisolated(unsafe) on the captured body to suppress Swift 6
        // Sendable warnings when crossing the isolation boundary.
        // This is safe because Params/R are decoded from/encoded to JSON (value-like).
        nonisolated(unsafe) let safeBody = body
        self.body = { params in
            nonisolated(unsafe) let safeParams = params
            return try await safeBody(safeParams)
        }
    }
    
    /// Create a background async function.
    ///
    /// The body closure runs on the cooperative thread pool without actor isolation.
    /// Use this for CPU-intensive operations that don't touch UI.
    ///
    /// - Parameters:
    ///   - name: The function name
    ///   - argumentsCount: Number of arguments (0 or 1)
    ///   - backgroundBody: The async closure to execute on the cooperative thread pool
    public init(name: String, argumentsCount: Int, backgroundBody: @escaping (Params) async throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.requiresMainActor = false
        self.body = backgroundBody
    }
    
    public func call(args: [Any]) async throws -> Any? {
        let params: Params = try decodeParams(from: args)
        let result = try await body(params)
        return try encodeResult(result)
    }
    
    private func decodeParams(from args: [Any]) throws -> Params {
        // VoidParams special handling - no params needed
        if Params.self == VoidParams.self {
            return VoidParams() as! Params
        }
        
        // Extract dictionary from args
        guard let dict = args.first as? [String: Any] else {
            throw NativeRPCError.invalidParams("Expected params dictionary, got: \(type(of: args.first ?? "nil"))")
        }
        
        // Use JSONDecoder to decode
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Params.self, from: data)
        } catch let error as DecodingError {
            throw NativeRPCError.invalidParams(describeDecodingError(error))
        }
    }
    
    private func encodeResult(_ result: R) throws -> Any {
        // For VoidResult, return nil
        if R.self == VoidResult.self {
            return NSNull()
        }
        
        // For basic types, return directly (they are already JSON-compatible)
        if result is Int || result is Double || result is String || result is Bool {
            return result
        }
        
        // For arrays and dictionaries of basic types, return directly
        if result is [Any] || result is [String: Any] {
            return result
        }
        
        // For complex Encodable types, encode to JSON-compatible dictionary/array
        let data = try JSONEncoder().encode(result)
        return try JSONSerialization.jsonObject(with: data)
    }
}

// MARK: - Other Definitions

/// Definition for service constants
public struct ConstantDefinition: AnyServiceDefinitionElement {
    public let name: String
    public let valueProvider: () -> Any?
    
    public init(name: String, valueProvider: @escaping () -> Any?) {
        self.name = name
        self.valueProvider = valueProvider
    }
}

/// Definition for service name
public struct ServiceNameDefinition: AnyServiceDefinitionElement {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

/// Definition for events that the service can emit
public struct EventsDefinition: AnyServiceDefinitionElement {
    public let names: [String]
    
    public init(names: [String]) {
        self.names = names
    }
}

/// Types of event observation
public enum EventObservingType {
    case startObserving
    case stopObserving
}

/// Definition for event observation callbacks
public struct EventObservingDefinition: AnyServiceDefinitionElement {
    public let type: EventObservingType
    public let event: String?  // nil means all events
    public let body: () -> Void
    
    public init(type: EventObservingType, event: String?, body: @escaping () -> Void) {
        self.type = type
        self.event = event
        self.body = body
    }
}

/// Lifecycle event types
public enum LifecycleType {
    case create
    case destroy
    case appEntersForeground
    case appEntersBackground
}

/// Definition for lifecycle callbacks
public struct LifecycleDefinition: AnyServiceDefinitionElement {
    public let type: LifecycleType
    public let body: () -> Void
    
    public init(type: LifecycleType, body: @escaping () -> Void) {
        self.type = type
        self.body = body
    }
}

// MARK: - Helper Functions

/// Describe a DecodingError for user-friendly error messages
private func describeDecodingError(_ error: DecodingError) -> String {
    switch error {
    case .keyNotFound(let key, _):
        return "Missing required key: '\(key.stringValue)'"
    case .typeMismatch(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        if path.isEmpty {
            return "Type mismatch: expected \(type)"
        }
        return "Type mismatch at '\(path)': expected \(type)"
    case .valueNotFound(let type, let context):
        let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        if path.isEmpty {
            return "Missing value: expected \(type)"
        }
        return "Missing value at '\(path)': expected \(type)"
    case .dataCorrupted(let context):
        return "Data corrupted: \(context.debugDescription)"
    @unknown default:
        return error.localizedDescription
    }
}
