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
/// ## New Architecture (v2.1)
///
/// Services are now:
/// - **Registered by type** at app startup via `NativeRPCServiceCenter`
/// - **Instantiated per-connection** when first called
/// - **Destroyed** when the connection closes
///
/// ```swift
/// // Define your service
/// class MyService: NativeRPCService {
///     // Required: provide static service name for registration
///     override class var serviceName: String { "myService" }
///     
///     // Required: init with context
///     required init(context: NativeRPCContext) {
///         super.init(context: context)
///     }
///     
///     @ServiceDefinitionBuilder
///     override func definition() -> ServiceDefinitionContainer {
///         // Name() is optional - auto-inferred from serviceName
///         
///         Function("getUserId") { () -> String? in
///             // Access connection-scoped context
///             self.context.get("userId")
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
/// // Register at app startup
/// NativeRPCServiceCenter.shared.register(MyService.self)
/// ```
///
/// Note: Not marked `Sendable` intentionally — services are managed by `NativeRPCStub`
/// which handles all synchronization internally via its concurrent queue.
/// Mutable state (`stub`, `_definitionContainer`) is accessed in controlled ways:
/// `stub` is set once on creation, and `_definitionContainer` is lazily initialized
/// (race-safe via single-threaded access pattern within the stub's queue).
///
/// If your subclass needs to be passed across isolation boundaries explicitly,
/// you can add `@unchecked Sendable` conformance to your subclass.
open class NativeRPCService: NativeRPCServiceProtocol {
    
    // MARK: - Static Properties
    
    /// The unique name identifying this service.
    /// Override this in subclasses to provide the service name.
    ///
    /// Example:
    /// ```swift
    /// override class var serviceName: String { "counter" }
    /// ```
    open class var serviceName: String {
        // Default implementation returns the class name (lowercased first letter)
        let className = String(describing: self)
        guard let first = className.first else { return "unnamed" }
        return first.lowercased() + className.dropFirst()
    }
    
    /// Connection types this service supports.
    /// Override to restrict which connection types can use this service.
    ///
    /// Example:
    /// ```swift
    /// override class var supportedConnectionTypes: Set<NativeRPCConnectionType> {
    ///     [.flutter, .webView]  // Only Flutter and WebView
    /// }
    /// ```
    open class var supportedConnectionTypes: Set<NativeRPCConnectionType> {
        [.flutter, .webView, .webSocket, .reactNative, .custom]
    }
    
    // MARK: - Instance Properties
    
    /// The context for this connection (contains connection info and shared storage)
    public let context: NativeRPCContext
    
    /// Weak reference to the stub that owns this service
    weak var stub: NativeRPCStub?
    
    /// Cached service definition container
    private var _definitionContainer: ServiceDefinitionContainer?
    
    /// Get or build the definition container
    public var definitionContainer: ServiceDefinitionContainer {
        if _definitionContainer == nil {
            _definitionContainer = definition()
        }
        return _definitionContainer!
    }
    
    /// The service name (from definition or class property)
    public var name: String {
        return definitionContainer.serviceName
    }
    
    // MARK: - Initialization
    
    /// Create a new service instance with the given context.
    ///
    /// Subclasses MUST override this initializer and call `super.init(context:)`.
    ///
    /// - Parameter context: The connection context
    public required init(context: NativeRPCContext) {
        self.context = context
        // Trigger create lifecycle
        _ = definitionContainer  // Force lazy init
        
        // Always set service name from class property (Name() is no longer used)
        definitionContainer.setServiceName(Self.serviceName)
        
        definitionContainer.triggerLifecycle(.create)
    }
    
    // MARK: - Definition (override in subclass)
    
    /// Override this method to define your service using the DSL.
    ///
    /// Use `@ServiceDefinitionBuilder` attribute when overriding.
    /// Note: `Name()` is optional - if not specified, the service name
    /// will be automatically inferred from `serviceName` class property.
    @ServiceDefinitionBuilder
    open func definition() -> ServiceDefinitionContainer {
        // Empty definition - subclasses should override
        // Service name will be auto-inferred from serviceName class property
    }
    
    // MARK: - Lifecycle
    
    /// Called when the service is being destroyed
    public func destroy() {
        definitionContainer.triggerLifecycle(.destroy)
        stub = nil
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
        
        guard let stub = stub else {
            // Service not attached to stub - silently ignore
            return
        }
        
        stub.sendEvent(service: self.name, event: name, params: data)
    }
    
    /// Send an event without throwing (logs error if event not declared)
    public func emit(_ name: String, data: Any? = nil) {
        do {
            try sendEvent(name, data: data)
        } catch {
            // Event not declared - silently ignore in emit
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
    public func onStartObserving(event: String? = nil, params: [String: Any]? = nil) {
        definitionContainer.startObserving(event: event, params: params)
    }
    
    /// Called when a client stops observing events
    public func onStopObserving(event: String? = nil) {
        definitionContainer.stopObserving(event: event)
    }
    
    // MARK: - Context Convenience
    
    /// Get the connection type (convenience accessor)
    public var connectionType: NativeRPCConnectionType {
        return context.connectionType
    }
}
