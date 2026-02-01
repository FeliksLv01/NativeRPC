// NativeRPCService.swift
// NativeRPC v2
//
// Base class for all NativeRPC services

import Foundation

// Note: This file depends on:
// - ServiceDefinitionBuilder.swift (ServiceDefinitionBuilder, ServiceDefinitionContainer)
// - ServiceDefinition.swift (LifecycleType, etc.)
// - NativeRPCMessage.swift (NativeRPCEvent)
// - NativeRPCError.swift (NativeRPCError)

// MARK: - Service Protocol

/// Protocol that all NativeRPC services must conform to
public protocol NativeRPCServiceProtocol: AnyObject {
    /// Build the service definition using DSL
    @ServiceDefinitionBuilder
    func definition() -> ServiceDefinitionContainer
    
    /// Called when the service is registered with a host
    func onRegistered(host: NativeRPCHostProtocol)
}

// MARK: - Host Protocol (forward declaration)

/// Protocol for the RPC host that manages services
public protocol NativeRPCHostProtocol: AnyObject {
    /// Send an event notification to all subscribers
    /// Notification format: {"method": "service.event", "params": {...}}
    func sendEvent(_ notification: NativeRPCNotification)
    
    /// Convenience method to send event with separate params
    func sendEvent(service: String, event: String, params: Any?)
    
    /// Get a registered service by name
    func getService(_ name: String) -> NativeRPCServiceProtocol?
}

// MARK: - NativeRPCService Base Class

/// Base class for NativeRPC services.
///
/// Subclass this and override `definition()` to define your service:
///
/// ```swift
/// class MyService: NativeRPCService {
///     @ServiceDefinitionBuilder
///     override func definition() -> ServiceDefinitionContainer {
///         Name("myService")
///
///         Constant("version") { "1.0.0" }
///
///         Function("add") { (a: Int, b: Int) -> Int in
///             a + b
///         }
///
///         AsyncFunction("fetchData") { (id: String) async throws -> Data in
///             try await self.repository.fetch(id)
///         }
///
///         Events("dataChanged", "statusUpdated")
///     }
/// }
/// ```
///
/// Note: Marked `@unchecked Sendable` because mutable state (`host`, `_definitionContainer`)
/// is accessed in controlled ways: `host` is set once on registration, and
/// `_definitionContainer` is lazily initialized (race-safe via single-threaded access pattern).
/// Safety invariant: Services are registered once and accessed through the host's synchronization.
open class NativeRPCService: NativeRPCServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Weak reference to the host
    public weak var host: NativeRPCHostProtocol?
    
    /// Cached service definition container
    private var _definitionContainer: ServiceDefinitionContainer?
    
    /// Get or build the definition container
    public var definitionContainer: ServiceDefinitionContainer {
        if _definitionContainer == nil {
            _definitionContainer = definition()
        }
        return _definitionContainer!
    }
    
    /// The service name (from definition)
    public var name: String {
        return definitionContainer.serviceName
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Definition (override in subclass)
    
    /// Override this method to define your service using the DSL.
    ///
    /// Use `@ServiceDefinitionBuilder` attribute when overriding.
    @ServiceDefinitionBuilder
    open func definition() -> ServiceDefinitionContainer {
        // Empty definition - subclasses should override
        Name("unnamed")
    }
    
    // MARK: - Lifecycle
    
    /// Called when the service is registered with a host
    open func onRegistered(host: NativeRPCHostProtocol) {
        self.host = host
        definitionContainer.triggerLifecycle(.create)
    }
    
    /// Called when the service is being destroyed
    public func destroy() {
        definitionContainer.triggerLifecycle(.destroy)
        host = nil
    }
    
    /// Called when the app enters foreground
    public func onForeground() {
        definitionContainer.triggerLifecycle(.appEntersForeground)
    }
    
    /// Called when the app enters background
    public func onBackground() {
        definitionContainer.triggerLifecycle(.appEntersBackground)
    }
    
    // MARK: - Event Sending
    
    /// Send an event to all subscribers.
    ///
    /// - Parameters:
    ///   - name: The event name (must be declared in `Events()`)
    ///   - data: Optional event data
    /// - Throws: `NativeRPCError.eventNotDeclared` if event name not in `Events()`
    public func sendEvent(_ name: String, data: Any? = nil) throws {
        guard definitionContainer.hasEvent(name) else {
            throw NativeRPCError.eventNotDeclared(name, service: self.name)
        }
        
        host?.sendEvent(service: self.name, event: name, params: data)
    }
    
    /// Send an event without throwing (logs error if event not declared)
    public func emit(_ name: String, data: Any? = nil) {
        do {
            try sendEvent(name, data: data)
        } catch {
            print("[NativeRPC] Error sending event '\(name)': \(error)")
        }
    }
    
    // MARK: - Method Handling
    
    /// Handle an incoming RPC call with params (JSON-RPC style)
    /// params can be: nil, dict, or array
    public func handleCall(method: String, params: Any?) async throws -> Any? {
        // Convert params to args array for backward compatibility with DSL
        let args: [Any]
        if let paramsArray = params as? [Any] {
            args = paramsArray
        } else if let paramsDict = params as? [String: Any] {
            // Pass dict as single argument
            args = [paramsDict]
        } else if params != nil {
            args = [params!]
        } else {
            args = []
        }
        return try await definitionContainer.call(method: method, args: args)
    }
    
    /// Handle an incoming RPC call with args array (legacy style)
    public func handleCall(method: String, args: [Any]) async throws -> Any? {
        return try await definitionContainer.call(method: method, args: args)
    }
    
    /// Check if this service can handle a method
    public func canHandle(method: String) -> Bool {
        return definitionContainer.canHandle(method: method)
    }
    
    // MARK: - Constants
    
    /// Get all constants as a dictionary
    public func getConstants() -> [String: Any?] {
        return definitionContainer.getConstants()
    }
    
    // MARK: - Subscription Handling
    
    /// Called when a client starts observing events
    public func onStartObserving(event: String? = nil) {
        definitionContainer.startObserving(event: event)
    }
    
    /// Called when a client stops observing events
    public func onStopObserving(event: String? = nil) {
        definitionContainer.stopObserving(event: event)
    }
}

// MARK: - Service Registry Helper

/// A type-erased service wrapper for registration
public struct AnyNativeRPCService {
    public let name: String
    public let service: NativeRPCServiceProtocol
    
    public init(_ service: NativeRPCService) {
        self.name = service.name
        self.service = service
    }
}
