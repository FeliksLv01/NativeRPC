// NativeRPCHost.swift
// NativeRPC v2
//
// Central RPC host that manages services, routing, and connections
// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)

import Foundation

// MARK: - NativeRPCHost

/// The central RPC host that manages services, handles message routing,
/// and maintains connections to clients.
///
/// Protocol: Simplified JSON-RPC 2.0
/// - Request:      {"id": "1", "method": "service.method", "params": {...}}
/// - Response:     {"id": "1", "result": ...}
/// - Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
/// - Notification: {"method": "service.event", "params": {...}}
///
/// Usage:
/// ```swift
/// let host = NativeRPCHost()
///
/// // Register services
/// host.register(AppService())
/// host.register(UserService())
///
/// // Connect to Flutter
/// let connection = FlutterMethodChannelConnection(channel: channel)
/// host.addConnection(connection)
/// ```
///
/// Note: Marked `@unchecked Sendable` because all mutable state is protected
/// by the internal `queue` (concurrent DispatchQueue with barrier writes).
/// Safety invariant: All mutations use `.barrier` flag, reads use `queue.sync`.
public final class NativeRPCHost: NativeRPCHostProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Registered services by name
    private var services: [String: NativeRPCService] = [:]
    
    /// Active connections
    private var connections: [NativeRPCConnection] = []
    
    /// Event subscriptions: [eventFullName: Set<connectionId>]
    /// where eventFullName = "service.event"
    private var subscriptions: [String: Set<String>] = [:]
    
    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.nativerpc.host", attributes: .concurrent)
    
    /// JSON encoder for messages
    private let encoder = JSONEncoder()
    
    // MARK: - Initialization
    
    public init() {
        encoder.outputFormatting = .sortedKeys
    }
    
    // MARK: - Service Registration
    
    /// Register a service with the host.
    ///
    /// - Parameter service: The service to register
    public func register(_ service: NativeRPCService) {
        let name = service.name
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if self.services[name] != nil {
                print("[NativeRPC] Warning: Service '\(name)' is already registered, replacing...")
            }
            
            self.services[name] = service
            service.onRegistered(host: self)
            
            print("[NativeRPC] Registered service: \(name)")
        }
    }
    
    /// Register multiple services at once
    public func register(_ services: NativeRPCService...) {
        for service in services {
            register(service)
        }
    }
    
    /// Unregister a service by name
    public func unregister(name: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let service = self.services.removeValue(forKey: name) {
                service.destroy()
                // Remove all subscriptions for this service
                self.subscriptions = self.subscriptions.filter { !$0.key.hasPrefix("\(name).") }
                print("[NativeRPC] Unregistered service: \(name)")
            }
        }
    }
    
    /// Get a registered service by name
    public func getService(_ name: String) -> NativeRPCServiceProtocol? {
        var result: NativeRPCServiceProtocol?
        queue.sync {
            result = services[name]
        }
        return result
    }
    
    // MARK: - Connection Management
    
    /// Add a connection to the host
    public func addConnection(_ connection: NativeRPCConnection) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.connections.append(connection)
            connection.onMessage = { [weak self] data in
                self?.handleIncomingMessage(data, from: connection)
            }
            
            print("[NativeRPC] Added connection: \(connection.id)")
        }
    }
    
    /// Remove a connection from the host
    public func removeConnection(_ connection: NativeRPCConnection) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.connections.removeAll { $0.id == connection.id }
            
            // Remove all subscriptions for this connection
            for (event, var connectionIds) in self.subscriptions {
                connectionIds.remove(connection.id)
                self.subscriptions[event] = connectionIds
            }
            
            print("[NativeRPC] Removed connection: \(connection.id)")
        }
    }
    
    // MARK: - Message Handling
    
    /// Handle an incoming message from a connection
    private func handleIncomingMessage(_ data: Data, from connection: NativeRPCConnection) {
        Task {
            do {
                let message = try NativeRPCMessageParser.parse(data)
                
                switch message {
                case .call(let request):
                    await handleCallRequest(request, from: connection)
                    
                case .subscribe(let request):
                    handleSubscribe(request, from: connection)
                    
                case .unsubscribe(let request):
                    handleUnsubscribe(request, from: connection)
                }
            } catch let error as NativeRPCError {
                sendError(id: "unknown", error: error, to: connection)
            } catch {
                let rpcError = NativeRPCError.parseError(error.localizedDescription)
                sendError(id: "unknown", error: rpcError, to: connection)
            }
        }
    }
    
    /// Handle a call request
    /// Request format: {"id": "1", "method": "service.method", "params": {...}}
    private func handleCallRequest(_ request: NativeRPCRequest, from connection: NativeRPCConnection) async {
        let serviceName = request.service
        let methodName = request.methodName
        
        // Find the service
        guard let service = services[serviceName] else {
            let error = NativeRPCError.serviceNotFound(serviceName)
            sendError(id: request.id, error: error, to: connection)
            return
        }
        
        // Check if method exists
        guard service.canHandle(method: methodName) else {
            let error = NativeRPCError.methodNotFound(methodName, service: serviceName)
            sendError(id: request.id, error: error, to: connection)
            return
        }
        
        // Get params (can be dict or array or nil)
        let params = request.params
        
        do {
            // Call the method
            let result = try await service.handleCall(method: methodName, params: params)
            
            // Send success response: {"id": "1", "result": ...}
            let response = NativeRPCResponse(id: request.id, result: result)
            sendResponse(response, to: connection)
        } catch let error as NativeRPCError {
            sendError(id: request.id, error: error, to: connection)
        } catch {
            let rpcError = NativeRPCError.internalError(error.localizedDescription)
            sendError(id: request.id, error: rpcError, to: connection)
        }
    }
    
    /// Handle a subscribe request
    /// Request format: {"id": "1", "method": "rpc.subscribe", "params": {"event": "service.event"}}
    private func handleSubscribe(_ request: NativeRPCSubscribeRequest, from connection: NativeRPCConnection) {
        let serviceName = request.service
        let eventName = request.eventName
        let eventFullName = request.event  // "service.event"
        
        // Validate service exists
        guard let service = services[serviceName] else {
            let error = NativeRPCError.serviceNotFound(serviceName)
            sendError(id: request.id, error: error, to: connection)
            return
        }
        
        // Validate event is declared
        guard service.definitionContainer.hasEvent(eventName) else {
            let error = NativeRPCError.eventNotDeclared(eventName, service: serviceName)
            sendError(id: request.id, error: error, to: connection)
            return
        }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Add subscription
            var subscribers = self.subscriptions[eventFullName] ?? []
            let isFirstSubscriber = subscribers.isEmpty
            subscribers.insert(connection.id)
            self.subscriptions[eventFullName] = subscribers
            
            // Notify service if this is the first subscriber
            if isFirstSubscriber {
                service.onStartObserving(event: eventName)
            }
            
            // Send success response: {"id": "1", "result": true}
            let response = NativeRPCResponse(id: request.id, result: true)
            self.sendResponse(response, to: connection)
        }
    }
    
    /// Handle an unsubscribe request
    /// Request format: {"id": "1", "method": "rpc.unsubscribe", "params": {"event": "service.event"}}
    private func handleUnsubscribe(_ request: NativeRPCUnsubscribeRequest, from connection: NativeRPCConnection) {
        let serviceName = request.service
        let eventName = request.eventName
        let eventFullName = request.event  // "service.event"
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var subscribers = self.subscriptions[eventFullName] ?? []
            subscribers.remove(connection.id)
            
            let noMoreSubscribers = subscribers.isEmpty
            self.subscriptions[eventFullName] = subscribers
            
            // Notify service if no more subscribers
            if noMoreSubscribers, let service = self.services[serviceName] {
                service.onStopObserving(event: eventName)
            }
            
            // Send success response: {"id": "1", "result": true}
            let response = NativeRPCResponse(id: request.id, result: true)
            self.sendResponse(response, to: connection)
        }
    }
    
    // MARK: - Event Sending (NativeRPCHostProtocol)
    
    /// Send an event notification to all subscribers
    /// Notification format: {"method": "service.event", "params": {...}}
    public func sendEvent(_ notification: NativeRPCNotification) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let eventFullName = notification.method  // "service.event"
            
            // Find subscribers for this event
            guard let subscriberIds = self.subscriptions[eventFullName], !subscriberIds.isEmpty else {
                return
            }
            
            // Encode the notification
            guard let data = try? self.encoder.encode(notification) else {
                print("[NativeRPC] Failed to encode notification: \(eventFullName)")
                return
            }
            
            // Send to all subscribed connections
            for connection in self.connections {
                if subscriberIds.contains(connection.id) {
                    connection.send(data)
                }
            }
        }
    }
    
    /// Convenience method to send event with service, event name, and params
    public func sendEvent(service: String, event: String, params: Any? = nil) {
        let notification = NativeRPCNotification(service: service, event: event, params: params)
        sendEvent(notification)
    }
    
    // MARK: - Response Helpers
    
    private func sendResponse(_ response: NativeRPCResponse, to connection: NativeRPCConnection) {
        guard let data = try? encoder.encode(response) else {
            print("[NativeRPC] Failed to encode response")
            return
        }
        connection.send(data)
    }
    
    private func sendError(id: String, error: NativeRPCError, to connection: NativeRPCConnection) {
        let response = NativeRPCErrorResponse(id: id, error: error)
        guard let data = try? encoder.encode(response) else {
            print("[NativeRPC] Failed to encode error response")
            return
        }
        connection.send(data)
    }
    
    // MARK: - Lifecycle
    
    /// Notify all services that app entered foreground
    public func onAppForeground() {
        queue.sync {
            for service in services.values {
                service.onForeground()
            }
        }
    }
    
    /// Notify all services that app entered background
    public func onAppBackground() {
        queue.sync {
            for service in services.values {
                service.onBackground()
            }
        }
    }
    
    /// Shutdown the host and all services
    public func shutdown() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Destroy all services
            for service in self.services.values {
                service.destroy()
            }
            self.services.removeAll()
            
            // Close all connections
            for connection in self.connections {
                connection.close()
            }
            self.connections.removeAll()
            
            // Clear subscriptions
            self.subscriptions.removeAll()
            
            print("[NativeRPC] Host shutdown complete")
        }
    }
    
    // MARK: - Introspection
    
    /// Get list of all registered service names
    public func getServiceNames() -> [String] {
        var result: [String] = []
        queue.sync {
            result = Array(services.keys)
        }
        return result
    }
    
    /// Get service info for introspection
    public func getServiceInfo(_ name: String) -> ServiceInfo? {
        var result: ServiceInfo?
        queue.sync {
            if let service = services[name] {
                result = ServiceInfo(
                    name: name,
                    methods: service.definitionContainer.getMethodNames(),
                    events: Array(service.definitionContainer.getEventNames()),
                    constants: service.getConstants().keys.map { $0 }
                )
            }
        }
        return result
    }
}

// MARK: - Supporting Types

/// Service information for introspection
public struct ServiceInfo {
    public let name: String
    public let methods: [String]
    public let events: [String]
    public let constants: [String]
}
