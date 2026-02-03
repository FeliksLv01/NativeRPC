// ServiceDefinition.swift
// NativeRPC v2
//
// DSL definitions and service definition container

import Foundation

// MARK: - Sendable Box Helper

/// Box for wrapping non-Sendable values when crossing isolation boundaries
/// Used internally to silence Swift 6 warnings for values we know are safe.
/// Safety: Only used within @unchecked Sendable types where we control access.
private struct UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T
}

// MARK: - VoidParams

/// Placeholder type for functions with no parameters
/// Used internally to satisfy Decodable constraint when no params are needed
public struct VoidParams: Codable {
    public init() {}
}

/// Placeholder type for functions that return nothing
/// Used internally to satisfy Encodable constraint when no result is returned
public struct VoidResult: Codable {
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
public final class SyncFunctionDefinition<Params: Decodable, R: Encodable>: AnySyncFunction {
    public let name: String
    public let argumentsCount: Int
    private let body: (Params) throws -> R
    
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
}

// MARK: - Async Function Definition (Swift Concurrency)

/// Asynchronous function definition with Codable params support
/// Supports Swift async/await
///
/// Note: Marked `@unchecked Sendable` because the `body` closure is captured
/// and may be called from different isolation contexts.
/// Safety invariant: Callers ensure arguments/results are safe to pass across boundaries.
public final class AsyncFunctionDefinition<Params: Decodable, R: Encodable>: AnyAsyncFunction, @unchecked Sendable {
    public let name: String
    public let argumentsCount: Int
    private let body: (Params) async throws -> R
    
    /// Queue to run the function on (nil = default async queue)
    public private(set) var queue: DispatchQueue?
    
    /// Whether to run on MainActor
    public private(set) var requiresMainActor: Bool = false
    
    public init(name: String, argumentsCount: Int, body: @escaping (Params) async throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) async throws -> Any? {
        let params: Params = try decodeParams(from: args)
        
        let result: R
        if requiresMainActor {
            // Box values to cross isolation boundary safely
            let paramsBox = UnsafeSendableBox(value: params)
            let bodyBox = UnsafeSendableBox(value: body)
            
            // Use withCheckedThrowingContinuation to properly bridge to MainActor
            result = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    Task { @MainActor in
                        do {
                            let r = try await bodyBox.value(paramsBox.value)
                            continuation.resume(returning: r)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else if let queue = queue {
            // Box values to cross isolation boundary safely
            let paramsBox = UnsafeSendableBox(value: params)
            let bodyBox = UnsafeSendableBox(value: body)
            
            result = try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    Task {
                        do {
                            let r = try await bodyBox.value(paramsBox.value)
                            continuation.resume(returning: r)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else {
            result = try await body(params)
        }
        
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
    
    /// Specify the queue to run the function on
    @discardableResult
    public func runOnQueue(_ queue: DispatchQueue?) -> Self {
        self.queue = queue
        return self
    }
    
    /// Run on the main queue
    @discardableResult
    public func runOnMain() -> Self {
        self.requiresMainActor = true
        return self
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
