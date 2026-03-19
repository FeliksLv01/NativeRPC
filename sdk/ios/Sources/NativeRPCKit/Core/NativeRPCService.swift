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
// - NativeRPCContext.swift (NativeRPCContext, NativeRPCConnectionType)
// - NativeRPCStub.swift (NativeRPCStub)

// MARK: - Service Protocol

/// Protocol that all NativeRPC services must conform to
public protocol NativeRPCServiceProtocol: AnyObject {
    /// Build the service definition using DSL
    @ServiceDefinitionBuilder
    func definition() -> ServiceDefinitionContainer
}

// MARK: - NativeRPCService Base Class

/// Base class for NativeRPC services.
///
/// Subclass this and override `definition()` to define your service.
/// Services are instantiated per-connection with a context that provides
/// connection-scoped state and configuration.
///
/// ## Architecture (v3.0)
///
/// The definition returned by `definition()` is **not cached by the service itself**.
/// Instead, the `NativeRPCStub` holds both the service and its definition via a
/// `ServiceHolder`, forming a tree-shaped ownership graph with no retain cycles.
/// This means closures in `definition()` can safely capture `self` without
/// `[weak self]`.
///
/// ```swift
/// class MyService: NativeRPCService {
///     override class var serviceName: String { "myService" }
///     
///     required init(context: NativeRPCContext) {
///         super.init(context: context)
///     }
///     
///     @ServiceDefinitionBuilder
///     override func definition() -> ServiceDefinitionContainer {
///         Function("getUserId") { () -> String? in
///             self.context.get("userId")  // no [weak self] needed
///         }
///         
///         AsyncFunction("fetchData") { (id: String) async throws -> Data in
///             try await self.repository.fetch(id)
///         }
///         
///         Events("dataChanged", "statusUpdated")
///     }
/// }
///
/// NativeRPCServiceCenter.shared.register(MyService.self)
/// ```
open class NativeRPCService: NativeRPCServiceProtocol {
    
    // MARK: - Static Properties
    
    /// The unique name identifying this service.
    /// Override this in subclasses to provide the service name.
    open class var serviceName: String {
        let className = String(describing: self)
        guard let first = className.first else { return "unnamed" }
        return first.lowercased() + className.dropFirst()
    }
    
    /// Connection types this service supports.
    /// Override to restrict which connection types can use this service.
    open class var supportedConnectionTypes: Set<NativeRPCConnectionType> {
        [.flutter, .webView, .webSocket, .reactNative, .custom]
    }
    
    // MARK: - Instance Properties
    
    /// The context for this connection (contains connection info and shared storage)
    public let context: NativeRPCContext
    
    /// Weak reference to the stub that owns this service
    weak var stub: NativeRPCStub?
    
    // MARK: - Initialization
    
    /// Create a new service instance with the given context.
    ///
    /// Subclasses MUST override this initializer and call `super.init(context:)`.
    ///
    /// - Parameter context: The connection context
    public required init(context: NativeRPCContext) {
        self.context = context
    }
    
    // MARK: - Definition (override in subclass)
    
    /// Override this method to define your service using the DSL.
    ///
    /// The returned `ServiceDefinitionContainer` is held externally by the stub,
    /// not by this service instance. This means closures can safely capture `self`
    /// without `[weak self]` — there is no retain cycle.
    @ServiceDefinitionBuilder
    open func definition() -> ServiceDefinitionContainer {
        // Empty definition - subclasses should override
    }
    
    // MARK: - Event Sending
    
    /// Send an event to all subscribers.
    ///
    /// - Parameters:
    ///   - name: The event name (must be declared in `Events()`)
    ///   - data: Optional event data
    /// - Throws: `NativeRPCError.eventNotDeclared` if event name not in `Events()`
    public func sendEvent(_ name: String, data: Any? = nil) throws {
        guard let stub = stub else { return }
        try stub.sendEventFromService(
            serviceName: Self.serviceName,
            event: name,
            data: data
        )
    }
    
    /// Send an event without throwing (logs error if event not declared)
    public func emit(_ name: String, data: Any? = nil) {
        do {
            try sendEvent(name, data: data)
        } catch {
            // Event not declared - silently ignore in emit
        }
    }
    
    // MARK: - Context Convenience
    
    /// Get the connection type (convenience accessor)
    public var connectionType: NativeRPCConnectionType {
        return context.connectionType
    }
}
