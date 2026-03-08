// DSLFactories.swift
// NativeRPC v2
//
// Factory functions for DSL syntax

import Foundation

// MARK: - Service Name

/// Defines the name of the service
///
/// - Note: **Deprecated in v2.2** - Service name is now automatically set from the
///   `serviceName` class property. You no longer need to call `Name()` in your definition.
///
/// ```swift
/// // Before (deprecated):
/// override func definition() -> ServiceDefinitionContainer {
///     Name("counter")  // ❌ No longer needed
///     Function("getValue") { ... }
/// }
///
/// // After:
/// override class var serviceName: String { "counter" }  // ✅ Define here
/// override func definition() -> ServiceDefinitionContainer {
///     Function("getValue") { ... }  // Name is auto-set
/// }
/// ```
@available(*, deprecated, message: "Name() is no longer needed. Service name is automatically set from the serviceName class property.")
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

// MARK: - Sync Functions

/// Creates a synchronous function with no parameters
///
/// Example:
/// ```swift
/// Function("getVersion") { () -> String in
///     "1.0.0"
/// }
/// ```
public func Function<R: Encodable>(_ name: String, _ body: @escaping () throws -> R) -> SyncFunctionDefinition<VoidParams, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 0) { _ in try body() }
}

/// Creates a synchronous function returning Void (no return value)
///
/// Example:
/// ```swift
/// Function("reset") { () in
///     self.counter = 0
/// }
/// ```
public func Function(_ name: String, _ body: @escaping () throws -> Void) -> SyncFunctionDefinition<VoidParams, VoidResult> {
    SyncFunctionDefinition(name: name, argumentsCount: 0) { _ in
        try body()
        return VoidResult()
    }
}

/// Creates a synchronous function with Codable parameters
///
/// Example:
/// ```swift
/// struct AddParams: Codable {
///     let a: Int
///     let b: Int
/// }
///
/// Function("add") { (params: AddParams) -> Int in
///     params.a + params.b
/// }
/// ```
public func Function<Params: Decodable, R: Encodable>(_ name: String, _ body: @escaping (Params) throws -> R) -> SyncFunctionDefinition<Params, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

/// Creates a synchronous function with Codable parameters returning Void
///
/// Example:
/// ```swift
/// struct SetValueParams: Codable {
///     let value: Int
/// }
///
/// Function("setValue") { (params: SetValueParams) in
///     self.value = params.value
/// }
/// ```
public func Function<Params: Decodable>(_ name: String, _ body: @escaping (Params) throws -> Void) -> SyncFunctionDefinition<Params, VoidResult> {
    SyncFunctionDefinition(name: name, argumentsCount: 1) { params in
        try body(params)
        return VoidResult()
    }
}

// MARK: - Async Functions (Swift Concurrency, MainActor by default)

/// Creates an asynchronous function with no parameters (Swift async/await)
///
/// The body runs on MainActor by default for UI safety.
/// Use `BackgroundAsyncFunction` for CPU-intensive operations that don't touch UI.
///
/// Example:
/// ```swift
/// AsyncFunction("fetchAll") { () async throws -> [Item] in
///     try await api.fetchAllItems()
/// }
/// ```
public func AsyncFunction<R: Encodable & Sendable>(_ name: String, _ body: @MainActor @escaping () async throws -> R) -> AsyncFunctionDefinition<VoidParams, R> {
    nonisolated(unsafe) let safeBody = body
    return AsyncFunctionDefinition(name: name, argumentsCount: 0) { _ in
        try await safeBody()
    }
}

/// Creates an asynchronous function with no parameters returning Void
///
/// The body runs on MainActor by default for UI safety.
///
/// Example:
/// ```swift
/// AsyncFunction("sync") { () async throws in
///     try await api.syncData()
/// }
/// ```
public func AsyncFunction(_ name: String, _ body: @MainActor @escaping () async throws -> Void) -> AsyncFunctionDefinition<VoidParams, VoidResult> {
    AsyncFunctionDefinition(name: name, argumentsCount: 0) { _ in
        try await body()
        return VoidResult()
    }
}

/// Creates an asynchronous function with Codable parameters (Swift async/await)
///
/// The body runs on MainActor by default for UI safety.
///
/// Example:
/// ```swift
/// struct FetchUserParams: Codable {
///     let id: String
/// }
///
/// AsyncFunction("fetchUser") { (params: FetchUserParams) async throws -> User in
///     try await api.getUser(params.id)
/// }
/// ```
public func AsyncFunction<Params: Decodable, R: Encodable>(_ name: String, _ body: @MainActor @escaping (Params) async throws -> R) -> AsyncFunctionDefinition<Params, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

/// Creates an asynchronous function with Codable parameters returning Void
///
/// The body runs on MainActor by default for UI safety.
///
/// Example:
/// ```swift
/// struct DeleteUserParams: Codable {
///     let id: String
/// }
///
/// AsyncFunction("deleteUser") { (params: DeleteUserParams) async throws in
///     try await api.deleteUser(params.id)
/// }
/// ```
public func AsyncFunction<Params: Decodable>(_ name: String, _ body: @MainActor @escaping (Params) async throws -> Void) -> AsyncFunctionDefinition<Params, VoidResult> {
    nonisolated(unsafe) let safeBody = body
    return AsyncFunctionDefinition(name: name, argumentsCount: 1) { params in
        nonisolated(unsafe) let safeParams = params
        try await safeBody(safeParams)
        return VoidResult()
    }
}

// MARK: - Background Async Functions (No actor isolation)

/// Creates a background asynchronous function with no parameters
///
/// The body runs on the cooperative thread pool without actor isolation.
/// Use this for CPU-intensive operations that don't touch UI.
///
/// Example:
/// ```swift
/// BackgroundAsyncFunction("compute") { () async throws -> Int in
///     try await heavyComputation()
/// }
/// ```
public func BackgroundAsyncFunction<R: Encodable>(_ name: String, _ body: @escaping () async throws -> R) -> AsyncFunctionDefinition<VoidParams, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 0, backgroundBody: { _ in try await body() })
}

/// Creates a background asynchronous function with no parameters returning Void
///
/// The body runs on the cooperative thread pool without actor isolation.
///
/// Example:
/// ```swift
/// BackgroundAsyncFunction("cleanup") { () async throws in
///     try await performCleanup()
/// }
/// ```
public func BackgroundAsyncFunction(_ name: String, _ body: @escaping () async throws -> Void) -> AsyncFunctionDefinition<VoidParams, VoidResult> {
    AsyncFunctionDefinition(name: name, argumentsCount: 0, backgroundBody: { _ in
        try await body()
        return VoidResult()
    })
}

/// Creates a background asynchronous function with Codable parameters
///
/// The body runs on the cooperative thread pool without actor isolation.
///
/// Example:
/// ```swift
/// BackgroundAsyncFunction("process") { (params: ProcessParams) async throws -> Result in
///     try await processData(params)
/// }
/// ```
public func BackgroundAsyncFunction<Params: Decodable, R: Encodable>(_ name: String, _ body: @escaping (Params) async throws -> R) -> AsyncFunctionDefinition<Params, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 1, backgroundBody: body)
}

/// Creates a background asynchronous function with Codable parameters returning Void
///
/// The body runs on the cooperative thread pool without actor isolation.
///
/// Example:
/// ```swift
/// BackgroundAsyncFunction("upload") { (params: UploadParams) async throws in
///     try await uploadData(params)
/// }
/// ```
public func BackgroundAsyncFunction<Params: Decodable>(_ name: String, _ body: @escaping (Params) async throws -> Void) -> AsyncFunctionDefinition<Params, VoidResult> {
    AsyncFunctionDefinition(name: name, argumentsCount: 1, backgroundBody: { params in
        try await body(params)
        return VoidResult()
    })
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

/// Called when a listener starts observing a specific event, receiving subscription params
///
/// Example:
/// ```swift
/// OnStartObserving("socketMessage") { params in
///     let topics = params?["topics"] as? [String] ?? []
///     // Set up subscription with topics
/// }
/// ```
public func OnStartObserving(_ event: String, _ body: @escaping ([String: Any]?) -> Void) -> EventObservingWithParamsDefinition {
    EventObservingWithParamsDefinition(type: .startObserving, event: event, body: body)
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
