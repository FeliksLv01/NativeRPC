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

/// Synchronous function definition with type safety
public final class SyncFunctionDefinition<Args, R>: AnySyncFunction {
    public let name: String
    public let argumentsCount: Int
    private let body: (Args) throws -> R
    
    public init(name: String, argumentsCount: Int, body: @escaping (Args) throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) throws -> Any? {
        let typedArgs: Args = try convertArgs(args)
        return try body(typedArgs)
    }
    
    private func convertArgs(_ args: [Any]) throws -> Args {
        if Args.self == Void.self {
            return () as! Args
        }
        
        // Try direct type match first
        if argumentsCount == 1, let arg = args.first as? Args {
            return arg
        }
        
        // Try using ArgumentConverter for single argument
        if argumentsCount == 1, let firstArg = args.first {
            if let converted = try? ArgumentConverter.convert(firstArg, to: Args.self) {
                return converted
            }
        }
        
        // Try tuple conversion
        if let tuple = tupleFromArray(args, type: Args.self) {
            return tuple
        }
        
        throw NativeRPCError.invalidArguments("Cannot convert arguments to expected type")
    }
}

// MARK: - Async Function Definition (Swift Concurrency)

/// Default queue for async function execution
private let defaultAsyncQueue = DispatchQueue(label: "com.nativerpc.async", qos: .userInitiated)

/// Asynchronous function definition with type safety
/// Supports Swift async/await
///
/// Note: Marked `@unchecked Sendable` because the `body` closure is captured
/// and may be called from different isolation contexts. The generic parameters
/// `Args` and `R` are not constrained to Sendable for API flexibility.
/// Safety invariant: Callers ensure arguments/results are safe to pass across boundaries.
public final class AsyncFunctionDefinition<Args, R>: AnyAsyncFunction, @unchecked Sendable {
    public let name: String
    public let argumentsCount: Int
    private let body: (Args) async throws -> R
    
    /// Queue to run the function on (nil = default async queue)
    public private(set) var queue: DispatchQueue?
    
    /// Whether to run on MainActor
    public private(set) var requiresMainActor: Bool = false
    
    public init(name: String, argumentsCount: Int, body: @escaping (Args) async throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) async throws -> Any? {
        let typedArgs: Args = try convertArgs(args)
        
        if requiresMainActor {
            // Box values to cross isolation boundary safely
            let argsBox = UnsafeSendableBox(value: typedArgs)
            let bodyBox = UnsafeSendableBox(value: body)
            
            // Use withCheckedThrowingContinuation to properly bridge to MainActor
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    Task { @MainActor in
                        do {
                            let result = try await bodyBox.value(argsBox.value)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else if let queue = queue {
            // Box values to cross isolation boundary safely
            let argsBox = UnsafeSendableBox(value: typedArgs)
            let bodyBox = UnsafeSendableBox(value: body)
            
            return try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    Task {
                        do {
                            let result = try await bodyBox.value(argsBox.value)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        } else {
            return try await body(typedArgs)
        }
    }
    
    private func convertArgs(_ args: [Any]) throws -> Args {
        if Args.self == Void.self {
            return () as! Args
        }
        
        // Try direct type match first
        if argumentsCount == 1, let arg = args.first as? Args {
            return arg
        }
        
        // Try using ArgumentConverter for single argument
        if argumentsCount == 1, let firstArg = args.first {
            if let converted = try? ArgumentConverter.convert(firstArg, to: Args.self) {
                return converted
            }
        }
        
        // Try tuple conversion
        if let tuple = tupleFromArray(args, type: Args.self) {
            return tuple
        }
        
        throw NativeRPCError.invalidArguments("Cannot convert arguments to expected type")
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

// MARK: - Promise-based Async Function Definition

/// Asynchronous function that uses Promise for callback-style async
/// Use this when bridging callback-based APIs
///
/// Note: Marked `@unchecked Sendable` because the `body` closure is captured
/// and may be called from different isolation contexts. The generic parameter
/// `Args` is not constrained to Sendable for API flexibility.
/// Safety invariant: Callers ensure arguments are safe to pass across boundaries.
public final class PromiseAsyncFunctionDefinition<Args>: AnyAsyncFunction, @unchecked Sendable {
    public let name: String
    public let argumentsCount: Int
    private let body: (Args, Promise) -> Void
    
    /// Queue to run the function on
    public private(set) var queue: DispatchQueue?
    
    /// Whether to run on MainActor
    public private(set) var requiresMainActor: Bool = false
    
    /// Timeout for the promise (default: 30 seconds)
    public private(set) var timeout: TimeInterval = 30.0
    
    public init(name: String, argumentsCount: Int, body: @escaping (Args, Promise) -> Void) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) async throws -> Any? {
        let typedArgs: Args = try convertArgs(args)
        
        // Box values to cross isolation boundary safely
        let argsBox = UnsafeSendableBox(value: typedArgs)
        let bodyBox = UnsafeSendableBox(value: body)
        let capturedRequiresMainActor = self.requiresMainActor
        let capturedQueue = self.queue
        let capturedTimeout = self.timeout
        
        return try await withCheckedThrowingContinuation { continuation in
            let hasResumed = AtomicBool(false)
            
            let promise = Promise(
                resolver: { value in
                    // Box the value to safely cross isolation boundaries
                    let valueBox = UnsafeSendableBox(value: value)
                    if hasResumed.compareAndSwap(expected: false, desired: true) {
                        continuation.resume(returning: valueBox.value)
                    }
                },
                rejecter: { error in
                    if hasResumed.compareAndSwap(expected: false, desired: true) {
                        continuation.resume(throwing: error)
                    }
                }
            )
            
            // Setup timeout
            let timeoutTask = DispatchWorkItem {
                if hasResumed.compareAndSwap(expected: false, desired: true) {
                    continuation.resume(throwing: NativeRPCError.timeout("Promise timed out after \(capturedTimeout) seconds"))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + capturedTimeout, execute: timeoutTask)
            
            // Execute the body with boxed values
            let executeBody: @Sendable () -> Void = {
                bodyBox.value(argsBox.value, promise)
            }
            
            if capturedRequiresMainActor {
                DispatchQueue.main.async(execute: executeBody)
            } else if let queue = capturedQueue {
                queue.async(execute: executeBody)
            } else {
                executeBody()
            }
        }
    }
    
    private func convertArgs(_ args: [Any]) throws -> Args {
        if Args.self == Void.self {
            return () as! Args
        }
        
        // Try direct type match first
        if argumentsCount == 1, let arg = args.first as? Args {
            return arg
        }
        
        // Try using ArgumentConverter for single argument
        if argumentsCount == 1, let firstArg = args.first {
            if let converted = try? ArgumentConverter.convert(firstArg, to: Args.self) {
                return converted
            }
        }
        
        // Try tuple conversion
        if let tuple = tupleFromArray(args, type: Args.self) {
            return tuple
        }
        
        throw NativeRPCError.invalidArguments("Cannot convert arguments to expected type")
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
    
    /// Set timeout for the promise
    @discardableResult
    public func withTimeout(_ seconds: TimeInterval) -> Self {
        self.timeout = seconds
        return self
    }
}

// MARK: - Atomic Bool Helper

private final class AtomicBool: @unchecked Sendable {
    private var value: Bool
    private let lock = NSLock()
    
    init(_ value: Bool) {
        self.value = value
    }
    
    func compareAndSwap(expected: Bool, desired: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        if value == expected {
            value = desired
            return true
        }
        return false
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

/// Convert array to tuple of expected type
private func tupleFromArray<T>(_ array: [Any], type: T.Type) -> T? {
    switch array.count {
    case 1:
        return array[0] as? T
    case 2:
        return (array[0], array[1]) as? T
    case 3:
        return (array[0], array[1], array[2]) as? T
    case 4:
        return (array[0], array[1], array[2], array[3]) as? T
    case 5:
        return (array[0], array[1], array[2], array[3], array[4]) as? T
    case 6:
        return (array[0], array[1], array[2], array[3], array[4], array[5]) as? T
    default:
        return nil
    }
}
