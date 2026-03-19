// NativeRPCStub.swift
// NativeRPC v2
//
// Per-connection message handler that manages service instances.
// Each connection has its own Stub, which lazily creates and holds service instances.

import Foundation

// MARK: - Stub Delegate Protocol

/// Protocol for receiving outgoing messages from the stub
protocol NativeRPCStubDelegate: AnyObject {
    /// Send a JSON message string to the client
    func sendMessage(_ jsonString: String)
}

// MARK: - ServiceHolder

/// Holds a service and its definition side-by-side.
///
/// This is the key to avoiding retain cycles: the service does NOT hold its own
/// definition. The stub holds both via this holder, forming a tree-shaped ownership:
///
/// ```
/// ServiceHolder (owned by Stub)
///   ├── service: NativeRPCService      (strong)
///   └── definition: ServiceDefinitionContainer  (strong)
///         └── closures ──strong──> service
/// ```
///
/// No cycle: service does not reference definition or holder.
struct ServiceHolder {
    let service: NativeRPCService
    let definition: ServiceDefinitionContainer
}

// MARK: - NativeRPCStub

/// Per-connection message handler that manages service instances.
///
/// Each connection has its own `NativeRPCStub`, which:
/// - Lazily creates service instances when first called
/// - Routes incoming RPC messages to the appropriate service
/// - Manages event subscriptions for this connection
/// - Destroys all service instances when the connection closes
///
/// Note: Marked `@unchecked Sendable` because mutable state (`holders`, `subscriptions`)
/// is protected by the internal `queue` (concurrent DispatchQueue with barrier writes).
/// Safety invariant: All mutations use `.barrier` flag, reads use `queue.sync`.
final class NativeRPCStub: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The context for this connection (contains connection info and shared storage)
    let context: NativeRPCContext
    
    /// Delegate to send outgoing messages
    weak var delegate: NativeRPCStubDelegate?
    
    /// Service holders for this connection, keyed by service name.
    /// Each holder owns both the service instance and its definition.
    private var holders: [String: ServiceHolder] = [:]
    
    /// Event subscriptions for this connection: [eventFullName: referenceCount]
    /// where eventFullName = "service.event"
    private var subscriptions: [String: Int] = [:]
    
    /// Serial queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.nativerpc.stub", attributes: .concurrent)
    
    /// JSON encoder for messages
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
    
    /// Connection ID for interceptors
    private let connectionId: String
    
    /// Interceptor context for this connection
    private var interceptorContext: NativeRPCInterceptorContext {
        NativeRPCInterceptorContext(
            connectionId: connectionId,
            connectionType: context.connectionType
        )
    }
    
    /// Reference to global interceptors
    private var interceptors: NativeRPCInterceptorChain {
        NativeRPCServiceCenter.shared.interceptors
    }
    
    // MARK: - Initialization
    
    /// Create a new stub for a connection
    ///
    /// - Parameter context: The context for this connection
    init(context: NativeRPCContext) {
        self.context = context
        self.connectionId = UUID().uuidString
        
        // Notify interceptors
        interceptors.didConnect(context: interceptorContext)
    }
    
    // MARK: - Service Access
    
    /// Get or create a service holder for this connection
    ///
    /// Services are lazily instantiated on first access and cached for the
    /// lifetime of the connection.
    ///
    /// - Parameter name: The service name
    /// - Returns: The service holder (service + definition)
    /// - Throws: `NativeRPCError` if service not found or connection type not supported
    func holder(named name: String) throws -> ServiceHolder {
        // Check if holder already exists
        var existingHolder: ServiceHolder?
        queue.sync {
            existingHolder = holders[name]
        }
        if let holder = existingHolder {
            return holder
        }
        
        // Get the service type from the service center
        guard let serviceType = NativeRPCServiceCenter.shared.serviceType(named: name) else {
            throw NativeRPCError.serviceNotFound(name)
        }
        
        // Check if service supports this connection type
        guard NativeRPCServiceCenter.shared.supportsConnectionType(
            serviceName: name,
            connectionType: context.connectionType
        ) else {
            throw NativeRPCError.connectionTypeNotSupported(
                service: name,
                connectionType: context.connectionTypeDescription
            )
        }
        
        // Create the service and its definition
        var resultHolder: ServiceHolder?
        var wasCreated = false
        queue.sync(flags: .barrier) {
            // Double-check in case another thread created it
            if let existing = holders[name] {
                resultHolder = existing
                return
            }
            
            // Create new instance
            let service = serviceType.init(context: context)
            service.stub = self
            
            // Build definition externally — service does NOT cache it
            let definition = service.definition()
            definition.setServiceName(type(of: service).serviceName)
            
            let holder = ServiceHolder(service: service, definition: definition)
            holders[name] = holder
            resultHolder = holder
            wasCreated = true
        }
        
        guard let holder = resultHolder else {
            throw NativeRPCError.internalError("Failed to create service instance: \(name)")
        }
        
        // Trigger lifecycle and interceptors outside the barrier
        if wasCreated {
            holder.definition.triggerLifecycle(.create)
            interceptors.didCreateService(name, context: interceptorContext)
        }
        
        return holder
    }
    
    // MARK: - Event Sending from Service
    
    /// Called by `NativeRPCService.emit()` / `sendEvent()`.
    /// Validates that the event is declared and forwards to the event system.
    func sendEventFromService(serviceName: String, event: String, data: Any?) throws {
        // Look up the holder to validate the event
        var holder: ServiceHolder?
        queue.sync {
            holder = holders[serviceName]
        }
        guard let holder else { return }
        
        guard holder.definition.hasEvent(event) else {
            throw NativeRPCError.eventNotDeclared(event, service: serviceName)
        }
        
        sendEvent(service: serviceName, event: event, params: data)
    }
    
    // MARK: - Message Handling
    
    /// Handle an incoming message from the client
    ///
    /// - Parameter data: The raw JSON message data
    func handleIncomingMessage(_ data: Data) {
        Task {
            do {
                let message = try NativeRPCMessageParser.parse(data)
                let startTime = Date()
                
                switch message {
                case .call(let request):
                    let requestInfo = NativeRPCRequestInfo(
                        id: request.id,
                        method: request.method,
                        service: request.service,
                        methodName: request.methodName,
                        type: .call,
                        params: request.params
                    )
                    interceptors.willProcessRequest(requestInfo, context: interceptorContext)
                    await handleCallRequest(request, requestInfo: requestInfo, startTime: startTime)
                    
                case .subscribe(let request):
                    let requestInfo = NativeRPCRequestInfo(
                        id: request.id,
                        method: request.event,
                        service: request.service,
                        methodName: request.eventName,
                        type: .subscribe,
                        params: request.params
                    )
                    interceptors.willProcessRequest(requestInfo, context: interceptorContext)
                    handleSubscribe(request, requestInfo: requestInfo, startTime: startTime)
                    
                case .unsubscribe(let request):
                    let requestInfo = NativeRPCRequestInfo(
                        id: request.id,
                        method: request.event,
                        service: request.service,
                        methodName: request.eventName,
                        type: .unsubscribe,
                        params: nil
                    )
                    interceptors.willProcessRequest(requestInfo, context: interceptorContext)
                    handleUnsubscribe(request, requestInfo: requestInfo, startTime: startTime)
                }
            } catch let error as NativeRPCError {
                sendError(id: "unknown", error: error)
            } catch {
                let rpcError = NativeRPCError.parseError(error.localizedDescription)
                sendError(id: "unknown", error: rpcError)
            }
        }
    }
    
    /// Handle a call request
    private func handleCallRequest(_ request: NativeRPCRequest, requestInfo: NativeRPCRequestInfo, startTime: Date) async {
        let serviceName = request.service
        let methodName = request.methodName
        
        // Get the holder (creates service + definition if needed)
        let holder: ServiceHolder
        do {
            holder = try self.holder(named: serviceName)
        } catch let error as NativeRPCError {
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: error, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: error, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        } catch {
            let rpcError = NativeRPCError.internalError(error.localizedDescription)
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: rpcError, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: rpcError, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        }
        
        // Check if method exists via definition
        guard holder.definition.canHandle(method: methodName) else {
            let error = NativeRPCError.methodNotFound(methodName, service: serviceName)
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: error, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: error, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        }
        
        // Convert params to args array
        let params = request.params
        let args: [Any]
        if let paramsArray = params as? [Any] {
            args = paramsArray
        } else if let paramsDict = params as? [String: Any] {
            args = [paramsDict]
        } else if params != nil {
            args = [params!]
        } else {
            args = []
        }
        
        do {
            // Call the method via definition
            let result = try await holder.definition.call(method: methodName, args: args)
            let duration = Date().timeIntervalSince(startTime)
            
            // Notify interceptors
            let responseInfo = NativeRPCResponseInfo.success(id: request.id, result: result, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            
            // Send success response
            let response = NativeRPCResponse(id: request.id, result: result)
            sendResponse(response, responseInfo: responseInfo, requestInfo: requestInfo)
        } catch let error as NativeRPCError {
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: error, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: error, responseInfo: responseInfo, requestInfo: requestInfo)
        } catch {
            let rpcError = NativeRPCError.internalError(error.localizedDescription)
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: rpcError, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: rpcError, responseInfo: responseInfo, requestInfo: requestInfo)
        }
    }
    
    /// Handle a subscribe request
    private func handleSubscribe(_ request: NativeRPCSubscribeRequest, requestInfo: NativeRPCRequestInfo, startTime: Date) {
        let serviceName = request.service
        let eventName = request.eventName
        let eventFullName = request.event
        
        // Get the holder (creates service + definition if needed)
        let holder: ServiceHolder
        do {
            holder = try self.holder(named: serviceName)
        } catch let error as NativeRPCError {
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: error, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: error, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        } catch {
            let rpcError = NativeRPCError.internalError(error.localizedDescription)
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: rpcError, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: rpcError, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        }
        
        // Validate event is declared via definition
        guard holder.definition.hasEvent(eventName) else {
            let error = NativeRPCError.eventNotDeclared(eventName, service: serviceName)
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.failure(id: request.id, error: error, duration: duration)
            interceptors.didProcessRequest(responseInfo, for: requestInfo, context: interceptorContext)
            sendError(id: request.id, error: error, responseInfo: responseInfo, requestInfo: requestInfo)
            return
        }
        
        // Capture definition for observing callback
        let definition = holder.definition
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Increment subscription count
            let currentCount = self.subscriptions[eventFullName] ?? 0
            let isFirstSubscriber = currentCount == 0
            self.subscriptions[eventFullName] = currentCount + 1
            
            // Notify definition if this is the first subscriber
            if isFirstSubscriber {
                definition.startObserving(event: eventName, params: request.params)
            }
            
            // Notify interceptors
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.success(id: request.id, result: true, duration: duration)
            self.interceptors.didProcessRequest(responseInfo, for: requestInfo, context: self.interceptorContext)
            
            // Send success response
            let response = NativeRPCResponse(id: request.id, result: true)
            self.sendResponse(response, responseInfo: responseInfo, requestInfo: requestInfo)
        }
    }
    
    /// Handle an unsubscribe request
    private func handleUnsubscribe(_ request: NativeRPCUnsubscribeRequest, requestInfo: NativeRPCRequestInfo, startTime: Date) {
        let serviceName = request.service
        let eventName = request.eventName
        let eventFullName = request.event
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Decrement subscription count
            let currentCount = self.subscriptions[eventFullName] ?? 0
            let newCount = max(0, currentCount - 1)
            self.subscriptions[eventFullName] = newCount
            
            let noMoreSubscribers = newCount == 0
            
            // Notify definition if no more subscribers
            if noMoreSubscribers, let holder = self.holders[serviceName] {
                holder.definition.stopObserving(event: eventName)
            }
            
            // Notify interceptors
            let duration = Date().timeIntervalSince(startTime)
            let responseInfo = NativeRPCResponseInfo.success(id: request.id, result: true, duration: duration)
            self.interceptors.didProcessRequest(responseInfo, for: requestInfo, context: self.interceptorContext)
            
            // Send success response
            let response = NativeRPCResponse(id: request.id, result: true)
            self.sendResponse(response, responseInfo: responseInfo, requestInfo: requestInfo)
        }
    }
    
    // MARK: - Event Sending
    
    /// Send an event notification to the client
    ///
    /// This is called by services via `NativeRPCService.emit()`.
    /// The event is only sent if the client has subscribed to it.
    ///
    /// - Parameter notification: The event notification to send
    func sendEvent(_ notification: NativeRPCNotification) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let eventFullName = notification.method
            
            // Check if client is subscribed to this event
            guard let count = self.subscriptions[eventFullName], count > 0 else {
                return
            }
            
            // Parse service and event name
            let parts = eventFullName.split(separator: ".")
            let serviceName = parts.count >= 2 ? parts.dropLast().joined(separator: ".") : eventFullName
            let eventName = parts.last.map(String.init) ?? eventFullName
            
            // Create event info for interceptors
            let eventInfo = NativeRPCEventInfo(
                event: eventFullName,
                service: serviceName,
                eventName: eventName,
                params: notification.params?.value
            )
            
            // Notify interceptors before sending
            self.interceptors.willSendEvent(eventInfo, context: self.interceptorContext)
            let outgoingMessage = NativeRPCOutgoingMessage.event(eventInfo)
            self.interceptors.willSendMessage(outgoingMessage, context: self.interceptorContext)
            
            // Encode and send
            guard let data = try? self.encoder.encode(notification),
                  let jsonString = String(data: data, encoding: .utf8) else {
                return
            }
            
            self.delegate?.sendMessage(jsonString)
            
            // Notify interceptors after sending
            self.interceptors.didSendEvent(eventInfo, context: self.interceptorContext)
            self.interceptors.didSendMessage(outgoingMessage, context: self.interceptorContext)
        }
    }
    
    /// Convenience method to send event with service, event name, and params
    func sendEvent(service: String, event: String, params: Any? = nil) {
        let notification = NativeRPCNotification(service: service, event: event, params: params)
        sendEvent(notification)
    }
    
    // MARK: - Response Helpers
    
    private func sendResponse(_ response: NativeRPCResponse, responseInfo: NativeRPCResponseInfo? = nil, requestInfo: NativeRPCRequestInfo? = nil) {
        // Notify interceptors before sending
        if let responseInfo = responseInfo, let requestInfo = requestInfo {
            let outgoingMessage = NativeRPCOutgoingMessage.response(responseInfo, request: requestInfo)
            interceptors.willSendMessage(outgoingMessage, context: interceptorContext)
        }
        
        guard let data = try? encoder.encode(response),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        delegate?.sendMessage(jsonString)
        
        // Notify interceptors after sending
        if let responseInfo = responseInfo, let requestInfo = requestInfo {
            let outgoingMessage = NativeRPCOutgoingMessage.response(responseInfo, request: requestInfo)
            interceptors.didSendMessage(outgoingMessage, context: interceptorContext)
        }
    }
    
    private func sendError(id: String, error: NativeRPCError, responseInfo: NativeRPCResponseInfo? = nil, requestInfo: NativeRPCRequestInfo? = nil) {
        // Notify interceptors before sending
        if let responseInfo = responseInfo, let requestInfo = requestInfo {
            let outgoingMessage = NativeRPCOutgoingMessage.response(responseInfo, request: requestInfo)
            interceptors.willSendMessage(outgoingMessage, context: interceptorContext)
        }
        
        let response = NativeRPCErrorResponse(id: id, error: error)
        guard let data = try? encoder.encode(response),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        delegate?.sendMessage(jsonString)
        
        // Notify interceptors after sending
        if let responseInfo = responseInfo, let requestInfo = requestInfo {
            let outgoingMessage = NativeRPCOutgoingMessage.response(responseInfo, request: requestInfo)
            interceptors.didSendMessage(outgoingMessage, context: interceptorContext)
        }
    }
    
    // MARK: - Lifecycle
    
    /// Notify all services that app entered foreground
    func onAppForeground() {
        queue.sync {
            for holder in holders.values {
                holder.definition.triggerLifecycle(.appEntersForeground)
            }
        }
    }
    
    /// Notify all services that app entered background
    func onAppBackground() {
        queue.sync {
            for holder in holders.values {
                holder.definition.triggerLifecycle(.appEntersBackground)
            }
        }
    }
    
    /// Shutdown the stub and destroy all service instances
    ///
    /// Call this when the connection closes.
    func shutdown() {
        // Capture context before async to avoid race
        let ctx = interceptorContext
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Destroy all services and notify interceptors
            for (name, holder) in self.holders {
                holder.definition.triggerLifecycle(.destroy)
                holder.definition.teardown()
                self.interceptors.didDestroyService(name, context: ctx)
            }
            self.holders.removeAll()
            
            // Clear subscriptions
            self.subscriptions.removeAll()
            
            // Clear context storage
            self.context.clearStorage()
            
            // Notify interceptors of disconnect
            self.interceptors.didDisconnect(context: ctx)
        }
    }
    
    // MARK: - Introspection
    
    /// Get list of instantiated service names for this connection
    func getActiveServiceNames() -> [String] {
        var result: [String] = []
        queue.sync {
            result = Array(holders.keys)
        }
        return result.sorted()
    }
    
    /// Get list of active subscriptions for this connection
    func getActiveSubscriptions() -> [String] {
        var result: [String] = []
        queue.sync {
            result = subscriptions.filter { $0.value > 0 }.map { $0.key }
        }
        return result.sorted()
    }
}
