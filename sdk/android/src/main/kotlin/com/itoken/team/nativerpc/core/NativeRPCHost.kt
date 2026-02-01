// NativeRPCHost.kt
// NativeRPC v2
//
// Central RPC host that manages services, routing, and connections
//
// Protocol (simplified JSON-RPC 2.0):
// Request:      {"id": "1", "method": "service.method", "params": {...}}
// Response:     {"id": "1", "result": ...}
// Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
// Notification: {"method": "service.event", "params": {...}}

package com.itoken.team.nativerpc.core

import com.itoken.team.nativerpc.connection.NativeRPCConnection
import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.util.concurrent.ConcurrentHashMap

/**
 * The central RPC host that manages services, handles message routing,
 * and maintains connections to clients.
 *
 * Usage:
 * ```kotlin
 * val host = NativeRPCHost()
 *
 * // Register services
 * host.register(AppService())
 * host.register(UserService())
 *
 * // Connect to Flutter
 * val connection = FlutterMethodChannelConnection(channel)
 * host.addConnection(connection)
 * ```
 */
class NativeRPCHost : NativeRPCHostProtocol {
    
    // MARK: - Properties
    
    /** Registered services by name */
    private val services = ConcurrentHashMap<String, NativeRPCService>()
    
    /** Active connections */
    private val connections = mutableListOf<NativeRPCConnection>()
    private val connectionsLock = Any()
    
    /** Event subscriptions: [fullEventName: Set<connectionId>] */
    private val subscriptions = ConcurrentHashMap<String, MutableSet<String>>()
    
    /** Coroutine scope for async operations */
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /** JSON serializer */
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    // MARK: - Service Registration
    
    /**
     * Register a service with the host.
     *
     * @param service The service to register
     */
    fun register(service: NativeRPCService) {
        val name = service.name
        
        if (services.containsKey(name)) {
            println("[NativeRPC] Warning: Service '$name' is already registered, replacing...")
        }
        
        services[name] = service
        service.onRegistered(this)
        
        println("[NativeRPC] Registered service: $name")
    }
    
    /**
     * Register multiple services at once
     */
    fun register(vararg services: NativeRPCService) {
        for (service in services) {
            register(service)
        }
    }
    
    /**
     * Unregister a service by name
     */
    fun unregister(name: String) {
        services.remove(name)?.let { service ->
            service.destroy()
            // Remove all subscriptions for this service
            subscriptions.keys.filter { it.startsWith("$name.") }.forEach { subscriptions.remove(it) }
            println("[NativeRPC] Unregistered service: $name")
        }
    }
    
    /**
     * Get a registered service by name
     */
    override fun getService(name: String): NativeRPCService? {
        return services[name]
    }
    
    // MARK: - Connection Management
    
    /**
     * Add a connection to the host
     */
    fun addConnection(connection: NativeRPCConnection) {
        synchronized(connectionsLock) {
            connections.add(connection)
            connection.onMessage = { data ->
                handleIncomingMessage(data, connection)
            }
            println("[NativeRPC] Added connection: ${connection.id}")
        }
    }
    
    /**
     * Remove a connection from the host
     */
    fun removeConnection(connection: NativeRPCConnection) {
        synchronized(connectionsLock) {
            connections.removeAll { it.id == connection.id }
            
            // Remove all subscriptions for this connection
            for ((_, connectionIds) in subscriptions) {
                connectionIds.remove(connection.id)
            }
            
            println("[NativeRPC] Removed connection: ${connection.id}")
        }
    }
    
    // MARK: - Message Handling
    
    /**
     * Handle an incoming message from a connection
     */
    private fun handleIncomingMessage(data: String, connection: NativeRPCConnection) {
        scope.launch {
            try {
                val incomingMessage = parseMessage(data)
                
                when (incomingMessage) {
                    is NativeRPCIncomingMessage.Call -> {
                        handleCallRequest(incomingMessage.request, connection)
                    }
                    is NativeRPCIncomingMessage.Subscribe -> {
                        handleSubscribe(incomingMessage.request, connection)
                    }
                    is NativeRPCIncomingMessage.Unsubscribe -> {
                        handleUnsubscribe(incomingMessage.request, connection)
                    }
                }
            } catch (e: NativeRPCError) {
                sendError("unknown", e, connection)
            } catch (e: Exception) {
                val rpcError = NativeRPCError.parseError(e.message)
                sendError("unknown", rpcError, connection)
            }
        }
    }
    
    /**
     * Parse incoming JSON message and determine its type
     */
    private fun parseMessage(data: String): NativeRPCIncomingMessage {
        val jsonObject = try {
            json.parseToJsonElement(data).jsonObject
        } catch (e: Exception) {
            throw NativeRPCError.parseError("Invalid JSON")
        }
        
        // Check for id (required for requests)
        val id = jsonObject["id"]?.jsonPrimitive?.contentOrNull
            ?: throw NativeRPCError.invalidRequest("Missing id in request")
        
        // Check for method (required)
        val method = jsonObject["method"]?.jsonPrimitive?.contentOrNull
            ?: throw NativeRPCError.invalidRequest("Missing method in request")
        
        val params = jsonObject["params"]
        
        // Check for special RPC methods
        when (method) {
            "rpc.subscribe" -> {
                val event = (params as? JsonObject)?.get("event")?.jsonPrimitive?.contentOrNull
                    ?: throw NativeRPCError.invalidParams("rpc.subscribe requires params.event")
                return NativeRPCIncomingMessage.Subscribe(NativeRPCSubscribeRequest(id, event))
            }
            "rpc.unsubscribe" -> {
                val event = (params as? JsonObject)?.get("event")?.jsonPrimitive?.contentOrNull
                    ?: throw NativeRPCError.invalidParams("rpc.unsubscribe requires params.event")
                return NativeRPCIncomingMessage.Unsubscribe(NativeRPCUnsubscribeRequest(id, event))
            }
            else -> {
                // Regular method call
                return NativeRPCIncomingMessage.Call(NativeRPCRequest(id, method, params))
            }
        }
    }
    
    /**
     * Handle a call request
     */
    private suspend fun handleCallRequest(request: NativeRPCRequest, connection: NativeRPCConnection) {
        val serviceName = request.service
        val methodName = request.methodName
        
        // Find the service
        val service = services[serviceName]
        if (service == null) {
            val error = NativeRPCError.serviceNotFound(serviceName)
            sendError(request.id, error, connection)
            return
        }
        
        // Check if method exists
        if (!service.canHandle(methodName)) {
            val error = NativeRPCError.methodNotFound(methodName, serviceName)
            sendError(request.id, error, connection)
            return
        }
        
        // Convert params to args list
        val args = paramsToArgs(request.params)
        
        try {
            // Call the method
            val result = service.handleCall(methodName, args)
            
            // Send success response
            val response = NativeRPCResponse.success(request.id, anyToJsonElement(result))
            sendResponse(response, connection)
        } catch (e: NativeRPCError) {
            sendError(request.id, e, connection)
        } catch (e: Exception) {
            val rpcError = NativeRPCError.internalError(e.message)
            sendError(request.id, rpcError, connection)
        }
    }
    
    /**
     * Convert params (JsonElement) to args list
     */
    private fun paramsToArgs(params: JsonElement?): List<Any?> {
        return when (params) {
            null -> emptyList()
            is JsonArray -> params.map { jsonElementToAny(it) }
            is JsonObject -> listOf(jsonElementToAny(params))
            else -> listOf(jsonElementToAny(params))
        }
    }
    
    /**
     * Handle a subscribe request
     */
    private fun handleSubscribe(request: NativeRPCSubscribeRequest, connection: NativeRPCConnection) {
        val serviceName = request.service
        val eventName = request.eventName
        val fullEventName = request.event
        
        // Validate service exists
        val service = services[serviceName]
        if (service == null) {
            val error = NativeRPCError.serviceNotFound(serviceName)
            sendError(request.id, error, connection)
            return
        }
        
        // Validate event is declared
        if (!service.definitionContainer.hasEvent(eventName)) {
            val error = NativeRPCError.eventNotDeclared(eventName, serviceName)
            sendError(request.id, error, connection)
            return
        }
        
        // Add subscription
        val eventSubscribers = subscriptions.getOrPut(fullEventName) { mutableSetOf() }
        
        val isFirstSubscriber = eventSubscribers.isEmpty()
        eventSubscribers.add(connection.id)
        
        // Notify service if this is the first subscriber
        if (isFirstSubscriber) {
            service.onStartObserving(eventName)
        }
        
        // Send success response
        val response = NativeRPCResponse.success(request.id, JsonPrimitive(true))
        sendResponse(response, connection)
    }
    
    /**
     * Handle an unsubscribe request
     */
    private fun handleUnsubscribe(request: NativeRPCUnsubscribeRequest, connection: NativeRPCConnection) {
        val serviceName = request.service
        val eventName = request.eventName
        val fullEventName = request.event
        
        val eventSubscribers = subscriptions[fullEventName]
        eventSubscribers?.remove(connection.id)
        
        val noMoreSubscribers = eventSubscribers?.isEmpty() == true
        
        // Notify service if no more subscribers
        if (noMoreSubscribers) {
            services[serviceName]?.onStopObserving(eventName)
        }
        
        // Send success response
        val response = NativeRPCResponse.success(request.id, JsonPrimitive(true))
        sendResponse(response, connection)
    }
    
    // MARK: - Event Sending (NativeRPCHostProtocol)
    
    /**
     * Send an event (notification) to all subscribers
     */
    override fun sendEvent(notification: NativeRPCNotification) {
        // Find subscribers for this event
        val subscriberIds = subscriptions[notification.method] ?: return
        
        // Encode the notification
        val data = try {
            json.encodeToString(NativeRPCNotification.serializer(), notification)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode notification: ${notification.method}")
            return
        }
        
        // Send to all subscribed connections
        synchronized(connectionsLock) {
            for (connection in connections) {
                if (subscriberIds.contains(connection.id)) {
                    connection.send(data)
                }
            }
        }
    }
    
    /**
     * Send an event with service, event name and data
     */
    fun sendEvent(service: String, event: String, params: JsonElement? = null) {
        val notification = NativeRPCNotification.create(service, event, params)
        sendEvent(notification)
    }
    
    // MARK: - Response Helpers
    
    private fun sendResponse(response: NativeRPCResponse, connection: NativeRPCConnection) {
        val data = try {
            json.encodeToString(NativeRPCResponse.serializer(), response)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode response")
            return
        }
        connection.send(data)
    }
    
    private fun sendError(id: String, error: NativeRPCError, connection: NativeRPCConnection) {
        val response = NativeRPCErrorResponse.from(id, error)
        val data = try {
            json.encodeToString(NativeRPCErrorResponse.serializer(), response)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode error response")
            return
        }
        connection.send(data)
    }
    
    // MARK: - Lifecycle
    
    /**
     * Notify all services that app entered foreground
     */
    fun onAppForeground() {
        for (service in services.values) {
            service.onForeground()
        }
    }
    
    /**
     * Notify all services that app entered background
     */
    fun onAppBackground() {
        for (service in services.values) {
            service.onBackground()
        }
    }
    
    /**
     * Shutdown the host and all services
     */
    fun shutdown() {
        // Cancel coroutine scope
        scope.cancel()
        
        // Destroy all services
        for (service in services.values) {
            service.destroy()
        }
        services.clear()
        
        // Close all connections
        synchronized(connectionsLock) {
            for (connection in connections) {
                connection.close()
            }
            connections.clear()
        }
        
        // Clear subscriptions
        subscriptions.clear()
        
        println("[NativeRPC] Host shutdown complete")
    }
    
    // MARK: - Introspection
    
    /**
     * Get list of all registered service names
     */
    fun getServiceNames(): List<String> {
        return services.keys.toList()
    }
    
    /**
     * Get service info for introspection
     */
    fun getServiceInfo(name: String): ServiceInfo? {
        val service = services[name] ?: return null
        return ServiceInfo(
            name = name,
            methods = service.definitionContainer.getMethodNames(),
            events = service.definitionContainer.getEventNames().toList(),
            constants = service.getConstants().keys.toList()
        )
    }
    
    // MARK: - JSON Helpers
    
    private fun jsonElementToAny(element: JsonElement): Any? {
        return when (element) {
            is JsonNull -> null
            is JsonPrimitive -> {
                when {
                    element.isString -> element.content
                    element.content == "true" -> true
                    element.content == "false" -> false
                    element.content.contains('.') -> element.content.toDoubleOrNull()
                    else -> element.content.toLongOrNull() ?: element.content.toIntOrNull() ?: element.content
                }
            }
            is JsonArray -> element.map { jsonElementToAny(it) }
            is JsonObject -> element.mapValues { jsonElementToAny(it.value) }
        }
    }
    
    private fun anyToJsonElement(value: Any?): JsonElement? {
        return when (value) {
            null -> null
            is String -> JsonPrimitive(value)
            is Number -> JsonPrimitive(value)
            is Boolean -> JsonPrimitive(value)
            is Map<*, *> -> {
                val map = value.entries.associate { 
                    (it.key as String) to (anyToJsonElement(it.value) ?: JsonNull)
                }
                JsonObject(map)
            }
            is List<*> -> {
                val list = value.map { anyToJsonElement(it) ?: JsonNull }
                JsonArray(list)
            }
            else -> JsonPrimitive(value.toString())
        }
    }
}

// MARK: - Supporting Types

/**
 * Service information for introspection
 */
data class ServiceInfo(
    val name: String,
    val methods: List<String>,
    val events: List<String>,
    val constants: List<String>
)
