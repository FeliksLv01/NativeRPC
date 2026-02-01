// ServiceDefinitionBuilder.swift
// NativeRPC v2
//
// Result builder for DSL syntax

import Foundation

// MARK: - Service Definition Container

/// Runtime container that stores all definitions for a service
public final class ServiceDefinitionContainer {
    
    /// The service name
    public private(set) var serviceName: String = ""
    
    /// Set the service name (used for auto-inference when Name() is not called)
    public func setServiceName(_ name: String) {
        serviceName = name
    }
    
    /// Registered sync functions
    private var syncFunctions: [String: AnySyncFunction] = [:]
    
    /// Registered async functions
    private var asyncFunctions: [String: AnyAsyncFunction] = [:]
    
    /// Registered constants
    private var constants: [String: () -> Any?] = [:]
    
    /// Declared event names
    private var eventNames: Set<String> = []
    
    /// Event observing callbacks
    private var startObservingCallbacks: [String?: [() -> Void]] = [:]
    private var stopObservingCallbacks: [String?: [() -> Void]] = [:]
    
    /// Lifecycle callbacks
    private var lifecycleCallbacks: [LifecycleType: [() -> Void]] = [:]
    
    public init() {}
    
    /// Initialize from an array of definition elements
    public init(elements: [AnyServiceDefinitionElement]) {
        for element in elements {
            register(element)
        }
    }
    
    /// Register a definition element
    public func register(_ element: AnyServiceDefinitionElement) {
        switch element {
        case let nameDef as ServiceNameDefinition:
            serviceName = nameDef.name
            
        case let syncFunc as AnySyncFunction:
            syncFunctions[syncFunc.name] = syncFunc
            
        case let asyncFunc as AnyAsyncFunction:
            asyncFunctions[asyncFunc.name] = asyncFunc
            
        case let constantDef as ConstantDefinition:
            constants[constantDef.name] = constantDef.valueProvider
            
        case let eventsDef as EventsDefinition:
            for name in eventsDef.names {
                eventNames.insert(name)
            }
            
        case let observingDef as EventObservingDefinition:
            switch observingDef.type {
            case .startObserving:
                var callbacks = startObservingCallbacks[observingDef.event] ?? []
                callbacks.append(observingDef.body)
                startObservingCallbacks[observingDef.event] = callbacks
            case .stopObserving:
                var callbacks = stopObservingCallbacks[observingDef.event] ?? []
                callbacks.append(observingDef.body)
                stopObservingCallbacks[observingDef.event] = callbacks
            }
            
        case let lifecycleDef as LifecycleDefinition:
            var callbacks = lifecycleCallbacks[lifecycleDef.type] ?? []
            callbacks.append(lifecycleDef.body)
            lifecycleCallbacks[lifecycleDef.type] = callbacks
            
        default:
            break
        }
    }
    
    // MARK: - Method Handling
    
    /// Check if this service can handle a specific method
    public func canHandle(method: String) -> Bool {
        return syncFunctions[method] != nil || asyncFunctions[method] != nil
    }
    
    /// Check if the method is asynchronous
    public func isAsync(method: String) -> Bool {
        return asyncFunctions[method] != nil
    }
    
    /// Call a method (async wrapper for both sync and async)
    public func call(method: String, args: [Any]) async throws -> Any? {
        if let asyncFunction = asyncFunctions[method] {
            return try await asyncFunction.call(args: args)
        }
        
        if let syncFunction = syncFunctions[method] {
            return try syncFunction.call(args: args)
        }
        
        throw NativeRPCError.methodNotFound(method, service: serviceName)
    }
    
    // MARK: - Constants
    
    /// Get all constants as a dictionary
    public func getConstants() -> [String: Any?] {
        var result: [String: Any?] = [:]
        for (name, provider) in constants {
            result[name] = provider()
        }
        return result
    }
    
    /// Get a specific constant
    public func getConstant(_ name: String) -> Any? {
        return constants[name]?()
    }
    
    // MARK: - Events
    
    /// Get all declared event names
    public func getEventNames() -> Set<String> {
        return eventNames
    }
    
    /// Check if an event is declared
    public func hasEvent(_ name: String) -> Bool {
        return eventNames.contains(name)
    }
    
    /// Trigger start observing callbacks
    public func startObserving(event: String? = nil) {
        // Call global callbacks (nil key)
        if let globalCallbacks = startObservingCallbacks[nil] {
            for callback in globalCallbacks {
                callback()
            }
        }
        
        // Call event-specific callbacks
        if let event = event, let eventCallbacks = startObservingCallbacks[event] {
            for callback in eventCallbacks {
                callback()
            }
        }
    }
    
    /// Trigger stop observing callbacks
    public func stopObserving(event: String? = nil) {
        if let globalCallbacks = stopObservingCallbacks[nil] {
            for callback in globalCallbacks {
                callback()
            }
        }
        
        if let event = event, let eventCallbacks = stopObservingCallbacks[event] {
            for callback in eventCallbacks {
                callback()
            }
        }
    }
    
    // MARK: - Lifecycle
    
    /// Trigger a lifecycle event
    public func triggerLifecycle(_ type: LifecycleType) {
        guard let callbacks = lifecycleCallbacks[type] else { return }
        for callback in callbacks {
            callback()
        }
    }
    
    /// Get list of all registered method names
    public func getMethodNames() -> [String] {
        let syncNames = Array(syncFunctions.keys)
        let asyncNames = Array(asyncFunctions.keys)
        return syncNames + asyncNames.filter { !syncNames.contains($0) }
    }
}

// MARK: - Service Definition Builder

/// A result builder for constructing service definitions using DSL syntax
@resultBuilder
public struct ServiceDefinitionBuilder {
    
    public static func buildBlock() -> [AnyServiceDefinitionElement] {
        []
    }
    
    public static func buildBlock(_ components: AnyServiceDefinitionElement...) -> [AnyServiceDefinitionElement] {
        components
    }
    
    public static func buildBlock(_ components: [AnyServiceDefinitionElement]...) -> [AnyServiceDefinitionElement] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [AnyServiceDefinitionElement]?) -> [AnyServiceDefinitionElement] {
        component ?? []
    }
    
    public static func buildEither(first component: [AnyServiceDefinitionElement]) -> [AnyServiceDefinitionElement] {
        component
    }
    
    public static func buildEither(second component: [AnyServiceDefinitionElement]) -> [AnyServiceDefinitionElement] {
        component
    }
    
    public static func buildArray(_ components: [[AnyServiceDefinitionElement]]) -> [AnyServiceDefinitionElement] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ expression: AnyServiceDefinitionElement) -> [AnyServiceDefinitionElement] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [AnyServiceDefinitionElement]) -> [AnyServiceDefinitionElement] {
        expression
    }
    
    public static func buildLimitedAvailability(_ component: [AnyServiceDefinitionElement]) -> [AnyServiceDefinitionElement] {
        component
    }
    
    public static func buildFinalResult(_ component: [AnyServiceDefinitionElement]) -> ServiceDefinitionContainer {
        ServiceDefinitionContainer(elements: component)
    }
}
