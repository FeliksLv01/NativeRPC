// NativeRPCHost.kt
// NativeRPC v2
//
// Central RPC host that manages services, routing, and connections

package com.itoken.team.nativerpc.core

import com.itoken.team.nativerpc.connection.NativeRPCConnection
import kotlinx.coroutines.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.concurrent.ConcurrentHashMap

/**
 * The central RPC host that manages services, handles message routing,
 * and maintains connections to clients.
 */
class NativeRPCHost : NativeRPCHostProtocol {
    
    /** Registered services by name */
    private val services = ConcurrentHashMap<String, NativeRPCService>()
    
    /** Active connections */
    private val connections = mutableListOf<NativeRPCConnection>()
    private val connectionsLock = Any()
    
    /** Event subscriptions: [serviceName: [eventName: Set<connectionId>]] */
    private val subscriptions = ConcurrentHashMap<String, ConcurrentHashMap<String, MutableSet<String>>>()
    
    /** Coroutine scope for async operations */
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /** JSON serializer */
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    /** Primary connection for Flutter plugin mode */
    private var primaryConnection: NativeRPCConnection? = null
    
    // MARK: - Initialization with Connection (for Flutter plugin)
    
    constructor()
    
    constructor(connection: NativeRPCConnection) {
        this.primaryConnection = connection
    }
    
    /**
     * Start the host (adds primary connection if set)
     */
    fun start() {
        primaryConnection?.let { addConnection(it) }
        println("[NativeRPC] Host started")
    }
    
    // MARK: - Synchronous Message Handling (for Flutter MethodChannel)
    
    /**
     * Handle a message string from Flutter and return response via callback.
     * This is used for request/response RPC calls through MethodChannel.
     */
    fun handleMessage(messageString: String, callback: (String?) -> Unit) {
        scope.launch {
            try {
                val request = json.decodeFromString<NativeRPCRequest>(messageString)
                
                // Find the service
                val service = services[request.service]
                if (service == null) {
                    val errorResponse = createErrorResponse(request.id, NativeRPCError.serviceNotFound(request.service))
                    withContext(Dispatchers.Main) { callback(errorResponse) }
                    return@launch
                }
                
                // Check if method exists
                if (!service.canHandle(request.method)) {
                    val errorResponse = createErrorResponse(request.id, NativeRPCError.methodNotFound(request.method, request.service))
                    withContext(Dispatchers.Main) { callback(errorResponse) }
                    return@launch
                }
                
                // Convert JsonElement args to Any
                val args = request.args.map { jsonElementToAny(it) }
                
                // Call the method
                val result = service.handleCall(request.method, args)
                
                // Create success response
                val response = NativeRPCResponse.success(request.id, anyToJsonElement(result))
                val responseString = json.encodeToString(NativeRPCResponse.serializer(), response)
                withContext(Dispatchers.Main) { callback(responseString) }
                
            } catch (e: NativeRPCError) {
                val errorResponse = createErrorResponse("unknown", e)
                withContext(Dispatchers.Main) { callback(errorResponse) }
            } catch (e: Exception) {
                val errorResponse = createErrorResponse("unknown", NativeRPCError.parseError(e.message ?: "Unknown error"))
                withContext(Dispatchers.Main) { callback(errorResponse) }
            }
        }
    }
    
    private fun createErrorResponse(id: String, error: NativeRPCError): String {
        val response = NativeRPCResponse.error(id, error)
        return try {
            json.encodeToString(NativeRPCResponse.serializer(), response)
        } catch (e: Exception) {
            "{\"id\":\"$id\",\"type\":\"error\",\"error\":{\"code\":\"INTERNAL_ERROR\",\"message\":\"Failed to encode error\"}}"
        }
    }
    
    // MARK: - Service Registration
    
    fun register(service: NativeRPCService) {
        val name = service.name
        
        if (services.containsKey(name)) {
            println("[NativeRPC] Warning: Service '$name' is already registered, replacing...")
        }
        
        services[name] = service
        service.onRegistered(this)
        
        println("[NativeRPC] Registered service: $name")
    }
    
    fun register(vararg services: NativeRPCService) {
        for (service in services) {
            register(service)
        }
    }
    
    fun unregister(name: String) {
        services.remove(name)?.let { service ->
            service.destroy()
            subscriptions.remove(name)
            println("[NativeRPC] Unregistered service: $name")
        }
    }
    
    override fun getService(name: String): NativeRPCService? {
        return services[name]
    }
    
    // MARK: - Connection Management
    
    fun addConnection(connection: NativeRPCConnection) {
        synchronized(connectionsLock) {
            connections.add(connection)
            connection.onMessage = { data ->
                handleIncomingMessage(data, connection)
            }
            println("[NativeRPC] Added connection: ${connection.id}")
        }
    }
    
    fun removeConnection(connection: NativeRPCConnection) {
        synchronized(connectionsLock) {
            connections.removeAll { it.id == connection.id }
            
            for ((_, events) in subscriptions) {
                for ((_, connectionIds) in events) {
                    connectionIds.remove(connection.id)
                }
            }
            
            println("[NativeRPC] Removed connection: ${connection.id}")
        }
    }
    
    // MARK: - Message Handling
    
    private fun handleIncomingMessage(data: String, connection: NativeRPCConnection) {
        scope.launch {
            try {
                val message = json.decodeFromString<GenericMessage>(data)
                
                when (message.type) {
                    NativeRPCMessageType.CALL -> {
                        val request = json.decodeFromString<NativeRPCRequest>(data)
                        handleCallRequest(request, connection)
                    }
                    
                    NativeRPCMessageType.SUBSCRIBE -> {
                        val subscription = json.decodeFromString<NativeRPCSubscription>(data)
                        handleSubscribe(subscription, connection)
                    }
                    
                    NativeRPCMessageType.UNSUBSCRIBE -> {
                        val subscription = json.decodeFromString<NativeRPCSubscription>(data)
                        handleUnsubscribe(subscription, connection)
                    }
                    
                    else -> {
                        val error = NativeRPCError.invalidRequest("Unexpected message type: ${message.type}")
                        sendError(message.id ?: "unknown", error, connection)
                    }
                }
            } catch (e: Exception) {
                val rpcError = NativeRPCError.parseError(e.message ?: "Unknown parse error")
                sendError("unknown", rpcError, connection)
            }
        }
    }
    
    private suspend fun handleCallRequest(request: NativeRPCRequest, connection: NativeRPCConnection) {
        val service = services[request.service]
        if (service == null) {
            val error = NativeRPCError.serviceNotFound(request.service)
            sendError(request.id, error, connection)
            return
        }
        
        if (!service.canHandle(request.method)) {
            val error = NativeRPCError.methodNotFound(request.method, request.service)
            sendError(request.id, error, connection)
            return
        }
        
        val args = request.args.map { jsonElementToAny(it) }
        
        try {
            val result = service.handleCall(request.method, args)
            val response = NativeRPCResponse.success(request.id, anyToJsonElement(result))
            sendResponse(response, connection)
        } catch (e: NativeRPCError) {
            sendError(request.id, e, connection)
        } catch (e: Exception) {
            val rpcError = NativeRPCError.internalError(e.message ?: "Unknown error")
            sendError(request.id, rpcError, connection)
        }
    }
    
    private fun handleSubscribe(subscription: NativeRPCSubscription, connection: NativeRPCConnection) {
        val serviceName = subscription.service
        val eventName = subscription.event
        
        val service = services[serviceName]
        if (service == null) {
            val error = NativeRPCError.serviceNotFound(serviceName)
            sendError(subscription.id, error, connection)
            return
        }
        
        if (!service.definitionContainer.hasEvent(eventName)) {
            val error = NativeRPCError.eventNotDeclared(eventName, serviceName)
            sendError(subscription.id, error, connection)
            return
        }
        
        val serviceSubscriptions = subscriptions.getOrPut(serviceName) { ConcurrentHashMap() }
        val eventSubscribers = serviceSubscriptions.getOrPut(eventName) { mutableSetOf() }
        
        val isFirstSubscriber = eventSubscribers.isEmpty()
        eventSubscribers.add(connection.id)
        
        if (isFirstSubscriber) {
            service.onStartObserving(eventName)
        }
        
        val response = NativeRPCResponse.success(subscription.id, kotlinx.serialization.json.JsonPrimitive(true))
        sendResponse(response, connection)
    }
    
    private fun handleUnsubscribe(subscription: NativeRPCSubscription, connection: NativeRPCConnection) {
        val serviceName = subscription.service
        val eventName = subscription.event
        
        val serviceSubscriptions = subscriptions[serviceName]
        val eventSubscribers = serviceSubscriptions?.get(eventName)
        
        eventSubscribers?.remove(connection.id)
        
        val noMoreSubscribers = eventSubscribers?.isEmpty() == true
        
        if (noMoreSubscribers) {
            services[serviceName]?.onStopObserving(eventName)
        }
        
        val response = NativeRPCResponse.success(subscription.id, kotlinx.serialization.json.JsonPrimitive(true))
        sendResponse(response, connection)
    }
    
    // MARK: - Event Sending
    
    override fun sendEvent(event: NativeRPCEvent) {
        val serviceSubscriptions = subscriptions[event.service] ?: return
        val subscriberIds = serviceSubscriptions[event.event] ?: return
        
        val data = try {
            json.encodeToString(NativeRPCEvent.serializer(), event)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode event: ${event.event}")
            return
        }
        
        synchronized(connectionsLock) {
            for (connection in connections) {
                if (subscriberIds.contains(connection.id)) {
                    connection.send(data)
                }
            }
        }
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
        val response = NativeRPCResponse.error(id, error)
        val data = try {
            json.encodeToString(NativeRPCResponse.serializer(), response)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode error response")
            return
        }
        connection.send(data)
    }
    
    // MARK: - Lifecycle
    
    fun onAppForeground() {
        for (service in services.values) {
            service.onForeground()
        }
    }
    
    fun onAppBackground() {
        for (service in services.values) {
            service.onBackground()
        }
    }
    
    fun shutdown() {
        scope.cancel()
        
        for (service in services.values) {
            service.destroy()
        }
        services.clear()
        
        synchronized(connectionsLock) {
            for (connection in connections) {
                connection.close()
            }
            connections.clear()
        }
        
        subscriptions.clear()
        
        println("[NativeRPC] Host shutdown complete")
    }
    
    // MARK: - Introspection
    
    fun getServiceNames(): List<String> {
        return services.keys.toList()
    }
    
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
    
    private fun jsonElementToAny(element: kotlinx.serialization.json.JsonElement): Any? {
        return when (element) {
            is kotlinx.serialization.json.JsonNull -> null
            is kotlinx.serialization.json.JsonPrimitive -> {
                when {
                    element.isString -> element.content
                    element.content == "true" -> true
                    element.content == "false" -> false
                    element.content.contains('.') -> element.content.toDoubleOrNull()
                    else -> element.content.toLongOrNull() ?: element.content.toIntOrNull() ?: element.content
                }
            }
            is kotlinx.serialization.json.JsonArray -> element.map { jsonElementToAny(it) }
            is kotlinx.serialization.json.JsonObject -> element.mapValues { jsonElementToAny(it.value) }
        }
    }
    
    private fun anyToJsonElement(value: Any?): kotlinx.serialization.json.JsonElement? {
        return when (value) {
            null -> null
            is String -> kotlinx.serialization.json.JsonPrimitive(value)
            is Number -> kotlinx.serialization.json.JsonPrimitive(value)
            is Boolean -> kotlinx.serialization.json.JsonPrimitive(value)
            is Map<*, *> -> {
                val map = value.entries.associate { 
                    (it.key as String) to (anyToJsonElement(it.value) ?: kotlinx.serialization.json.JsonNull)
                }
                kotlinx.serialization.json.JsonObject(map)
            }
            is List<*> -> {
                val list = value.map { anyToJsonElement(it) ?: kotlinx.serialization.json.JsonNull }
                kotlinx.serialization.json.JsonArray(list)
            }
            else -> kotlinx.serialization.json.JsonPrimitive(value.toString())
        }
    }
}

// MARK: - Supporting Types

@Serializable
private data class GenericMessage(
    val id: String? = null,
    val type: NativeRPCMessageType
)

data class ServiceInfo(
    val name: String,
    val methods: List<String>,
    val events: List<String>,
    val constants: List<String>
)
