// DSLFactories.swift
// NativeRPC v2
//
// Factory functions for DSL syntax

import Foundation

// MARK: - Service Name

/// Defines the name of the service
public func Name(_ name: String) -> ServiceNameDefinition {
    ServiceNameDefinition(name: name)
}

// MARK: - Constants

/// Defines a constant value
public func Constant(_ name: String, _ value: Any?) -> ConstantDefinition {
    ConstantDefinition(name: name) { value }
}

/// Defines a lazily-evaluated constant value
public func Constant(_ name: String, _ provider: @escaping () -> Any?) -> ConstantDefinition {
    ConstantDefinition(name: name, valueProvider: provider)
}

// MARK: - Sync Functions (0-6 arguments)

/// Creates a synchronous function with no arguments
public func Function<R>(_ name: String, _ body: @escaping () throws -> R) -> SyncFunctionDefinition<Void, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 0) { _ in try body() }
}

/// Creates a synchronous function with 1 argument
public func Function<A0, R>(_ name: String, _ body: @escaping (A0) throws -> R) -> SyncFunctionDefinition<A0, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

/// Creates a synchronous function with 2 arguments
public func Function<A0, A1, R>(_ name: String, _ body: @escaping (A0, A1) throws -> R) -> SyncFunctionDefinition<(A0, A1), R> {
    SyncFunctionDefinition(name: name, argumentsCount: 2) { args in try body(args.0, args.1) }
}

/// Creates a synchronous function with 3 arguments
public func Function<A0, A1, A2, R>(_ name: String, _ body: @escaping (A0, A1, A2) throws -> R) -> SyncFunctionDefinition<(A0, A1, A2), R> {
    SyncFunctionDefinition(name: name, argumentsCount: 3) { args in try body(args.0, args.1, args.2) }
}

/// Creates a synchronous function with 4 arguments
public func Function<A0, A1, A2, A3, R>(_ name: String, _ body: @escaping (A0, A1, A2, A3) throws -> R) -> SyncFunctionDefinition<(A0, A1, A2, A3), R> {
    SyncFunctionDefinition(name: name, argumentsCount: 4) { args in try body(args.0, args.1, args.2, args.3) }
}

/// Creates a synchronous function with 5 arguments
public func Function<A0, A1, A2, A3, A4, R>(_ name: String, _ body: @escaping (A0, A1, A2, A3, A4) throws -> R) -> SyncFunctionDefinition<(A0, A1, A2, A3, A4), R> {
    SyncFunctionDefinition(name: name, argumentsCount: 5) { args in try body(args.0, args.1, args.2, args.3, args.4) }
}

// MARK: - Async Functions with Swift Concurrency (0-6 arguments)

/// Creates an asynchronous function with no arguments (Swift async/await)
public func AsyncFunction<R>(_ name: String, _ body: @escaping () async throws -> R) -> AsyncFunctionDefinition<Void, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 0) { _ in try await body() }
}

/// Creates an asynchronous function with 1 argument (Swift async/await)
public func AsyncFunction<A0, R>(_ name: String, _ body: @escaping (A0) async throws -> R) -> AsyncFunctionDefinition<A0, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

/// Creates an asynchronous function with 2 arguments (Swift async/await)
public func AsyncFunction<A0, A1, R>(_ name: String, _ body: @escaping (A0, A1) async throws -> R) -> AsyncFunctionDefinition<(A0, A1), R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 2) { args in try await body(args.0, args.1) }
}

/// Creates an asynchronous function with 3 arguments (Swift async/await)
public func AsyncFunction<A0, A1, A2, R>(_ name: String, _ body: @escaping (A0, A1, A2) async throws -> R) -> AsyncFunctionDefinition<(A0, A1, A2), R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 3) { args in try await body(args.0, args.1, args.2) }
}

/// Creates an asynchronous function with 4 arguments (Swift async/await)
public func AsyncFunction<A0, A1, A2, A3, R>(_ name: String, _ body: @escaping (A0, A1, A2, A3) async throws -> R) -> AsyncFunctionDefinition<(A0, A1, A2, A3), R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 4) { args in try await body(args.0, args.1, args.2, args.3) }
}

/// Creates an asynchronous function with 5 arguments (Swift async/await)
public func AsyncFunction<A0, A1, A2, A3, A4, R>(_ name: String, _ body: @escaping (A0, A1, A2, A3, A4) async throws -> R) -> AsyncFunctionDefinition<(A0, A1, A2, A3, A4), R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 5) { args in try await body(args.0, args.1, args.2, args.3, args.4) }
}

// MARK: - Async Functions with Promise (Callback-style, 0-5 arguments + Promise)

/// Creates an asynchronous function with Promise only (no other arguments)
///
/// Example:
/// ```swift
/// AsyncFunction("fetchAll") { (promise: Promise) in
///     LegacyAPI.fetchAll { result, error in
///         if let error = error {
///             promise.reject(error)
///         } else {
///             promise.resolve(result)
///         }
///     }
/// }
/// ```
public func AsyncFunction(_ name: String, _ body: @escaping (Promise) -> Void) -> PromiseAsyncFunctionDefinition<Void> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 0) { _, promise in body(promise) }
}

/// Creates an asynchronous function with 1 argument + Promise
///
/// Example:
/// ```swift
/// AsyncFunction("fetchUser") { (id: String, promise: Promise) in
///     UserAPI.fetch(id) { user, error in
///         if let error = error {
///             promise.reject(error)
///         } else {
///             promise.resolve(user?.toDictionary())
///         }
///     }
/// }
/// ```
public func AsyncFunction<A0>(_ name: String, _ body: @escaping (A0, Promise) -> Void) -> PromiseAsyncFunctionDefinition<A0> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

/// Creates an asynchronous function with 2 arguments + Promise
public func AsyncFunction<A0, A1>(_ name: String, _ body: @escaping (A0, A1, Promise) -> Void) -> PromiseAsyncFunctionDefinition<(A0, A1)> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 2) { args, promise in body(args.0, args.1, promise) }
}

/// Creates an asynchronous function with 3 arguments + Promise
public func AsyncFunction<A0, A1, A2>(_ name: String, _ body: @escaping (A0, A1, A2, Promise) -> Void) -> PromiseAsyncFunctionDefinition<(A0, A1, A2)> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 3) { args, promise in body(args.0, args.1, args.2, promise) }
}

/// Creates an asynchronous function with 4 arguments + Promise
public func AsyncFunction<A0, A1, A2, A3>(_ name: String, _ body: @escaping (A0, A1, A2, A3, Promise) -> Void) -> PromiseAsyncFunctionDefinition<(A0, A1, A2, A3)> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 4) { args, promise in body(args.0, args.1, args.2, args.3, promise) }
}

/// Creates an asynchronous function with 5 arguments + Promise
public func AsyncFunction<A0, A1, A2, A3, A4>(_ name: String, _ body: @escaping (A0, A1, A2, A3, A4, Promise) -> Void) -> PromiseAsyncFunctionDefinition<(A0, A1, A2, A3, A4)> {
    PromiseAsyncFunctionDefinition(name: name, argumentsCount: 5) { args, promise in body(args.0, args.1, args.2, args.3, args.4, promise) }
}

// MARK: - Events

/// Declares the events that this service can emit
public func Events(_ names: String...) -> EventsDefinition {
    EventsDefinition(names: names)
}

/// Declares the events that this service can emit
public func Events(_ names: [String]) -> EventsDefinition {
    EventsDefinition(names: names)
}

// MARK: - Event Observing

/// Called when a listener starts observing any event
public func OnStartObserving(_ body: @escaping () -> Void) -> EventObservingDefinition {
    EventObservingDefinition(type: .startObserving, event: nil, body: body)
}

/// Called when a listener starts observing a specific event
public func OnStartObserving(_ event: String, _ body: @escaping () -> Void) -> EventObservingDefinition {
    EventObservingDefinition(type: .startObserving, event: event, body: body)
}

/// Called when a listener stops observing any event
public func OnStopObserving(_ body: @escaping () -> Void) -> EventObservingDefinition {
    EventObservingDefinition(type: .stopObserving, event: nil, body: body)
}

/// Called when a listener stops observing a specific event
public func OnStopObserving(_ event: String, _ body: @escaping () -> Void) -> EventObservingDefinition {
    EventObservingDefinition(type: .stopObserving, event: event, body: body)
}

// MARK: - Lifecycle

/// Called when the service is created
public func OnCreate(_ body: @escaping () -> Void) -> LifecycleDefinition {
    LifecycleDefinition(type: .create, body: body)
}

/// Called when the service is destroyed
public func OnDestroy(_ body: @escaping () -> Void) -> LifecycleDefinition {
    LifecycleDefinition(type: .destroy, body: body)
}

/// Called when the app enters foreground
public func OnAppEntersForeground(_ body: @escaping () -> Void) -> LifecycleDefinition {
    LifecycleDefinition(type: .appEntersForeground, body: body)
}

/// Called when the app enters background
public func OnAppEntersBackground(_ body: @escaping () -> Void) -> LifecycleDefinition {
    LifecycleDefinition(type: .appEntersBackground, body: body)
}
