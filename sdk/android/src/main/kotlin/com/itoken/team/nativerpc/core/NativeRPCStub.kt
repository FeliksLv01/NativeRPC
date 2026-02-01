// NativeRPCStub.kt
// NativeRPC v2
//
// Per-connection message handler that manages service instances.
// Each connection has its own Stub, which lazily creates and holds service instances.

package com.itoken.team.nativerpc.core

import kotlinx.coroutines.*
import kotlinx.serialization.json.*
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Interface for receiving outgoing messages from the stub
 */
interface NativeRPCStubDelegate {
    /** Send a message to the client */
    fun sendMessage(data: String)
}

/**
 * Per-connection message handler that manages service instances.
 *
 * Each connection has its own `NativeRPCStub`, which:
 * - Lazily creates service instances when first called
 * - Routes incoming RPC messages to the appropriate service
 * - Manages event subscriptions for this connection
 * - Destroys all service instances when the connection closes
 *
 * Usage:
 * ```kotlin
 * val context = NativeRPCContext(connectionType = NativeRPCConnectionType.FLUTTER)
 * val stub = NativeRPCStub(context)
 * stub.delegate = connection
 *
 * // When receiving a message from client:
 * stub.handleIncomingMessage(data)
 *
 * // When connection closes:
 * stub.shutdown()
 * ```
 */
class NativeRPCStub(
    /** The context for this connection */
    val context: NativeRPCContext
) {
    
    // MARK: - Properties
    
    /** Delegate to send outgoing messages */
    var delegate: NativeRPCStubDelegate? = null
    
    /** Instantiated services for this connection, keyed by service name */
    private val services = ConcurrentHashMap<String, NativeRPCService>()
    
    /** Event subscriptions for this connection: [eventFullName: referenceCount] */
    private val subscriptions = ConcurrentHashMap<String, Int>()
    
    /** Read-write lock for service access */
    private val servicesLock = ReentrantReadWriteLock()
    
    /** Coroutine scope for async operations */
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /** JSON serializer */
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    // MARK: - Service Access
    
    /**
     * Get or create a service instance for this connection
     *
     * Services are lazily instantiated on first access and cached for the
     * lifetime of the connection.
     *
     * @param name The service name
     * @return The service instance
     * @throws NativeRPCError if service not found or connection type not supported
     */
    @Throws(NativeRPCError::class)
    fun getService(name: String): NativeRPCService {
        // Check if service is already instantiated
        services[name]?.let { return it }
        
        // Get the service factory from the service center
        val factory = NativeRPCServiceCenter.getFactory(name)
            ?: throw NativeRPCError.serviceNotFound(name)
        
        // Check if service supports this connection type
        if (!NativeRPCServiceCenter.supportsConnectionType(name, context.connectionType)) {
            throw NativeRPCError.connectionTypeNotSupported(name, context.connectionTypeDescription)
        }
        
        // Create the service instance (with double-check locking)
        return servicesLock.write {
            // Double-check in case another thread created it
            services[name]?.let { return@write it }
            
            // Create new instance
            val instance = factory.create(context)
            instance.stub = this
            instance.internalContext = context
            
            // Always set service name from factory (Name() DSL is no longer used)
            instance.definitionContainer.setServiceName(name)
            
            services[name] = instance
            println("[NativeRPC] Created service instance: $name")
            instance
        }
    }
    
    // MARK: - Message Handling
    
    /**
     * Handle an incoming message from the client
     *
     * @param data The raw JSON message string
     */
    fun handleIncomingMessage(data: String) {
        scope.launch {
            try {
                val message = parseMessage(data)
                
                when (message) {
                    is NativeRPCIncomingMessage.Call -> {
                        handleCallRequest(message.request)
                    }
                    is NativeRPCIncomingMessage.Subscribe -> {
                        handleSubscribe(message.request)
                    }
                    is NativeRPCIncomingMessage.Unsubscribe -> {
                        handleUnsubscribe(message.request)
                    }
                }
            } catch (e: NativeRPCError) {
                sendError("unknown", e)
            } catch (e: Exception) {
                val rpcError = NativeRPCError.parseError(e.message)
                sendError("unknown", rpcError)
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
        return when (method) {
            "rpc.subscribe" -> {
                val event = (params as? JsonObject)?.get("event")?.jsonPrimitive?.contentOrNull
                    ?: throw NativeRPCError.invalidParams("rpc.subscribe requires params.event")
                NativeRPCIncomingMessage.Subscribe(NativeRPCSubscribeRequest(id, event))
            }
            "rpc.unsubscribe" -> {
                val event = (params as? JsonObject)?.get("event")?.jsonPrimitive?.contentOrNull
                    ?: throw NativeRPCError.invalidParams("rpc.unsubscribe requires params.event")
                NativeRPCIncomingMessage.Unsubscribe(NativeRPCUnsubscribeRequest(id, event))
            }
            else -> {
                // Regular method call
                NativeRPCIncomingMessage.Call(NativeRPCRequest(id, method, params))
            }
        }
    }
    
    /**
     * Handle a call request
     */
    private suspend fun handleCallRequest(request: NativeRPCRequest) {
        val serviceName = request.service
        val methodName = request.methodName
        
        // Get the service (creates if needed)
        val service: NativeRPCService
        try {
            service = getService(serviceName)
        } catch (e: NativeRPCError) {
            sendError(request.id, e)
            return
        } catch (e: Exception) {
            sendError(request.id, NativeRPCError.internalError(e.message))
            return
        }
        
        // Check if method exists
        if (!service.canHandle(methodName)) {
            val error = NativeRPCError.methodNotFound(methodName, serviceName)
            sendError(request.id, error)
            return
        }
        
        // Convert params to args list
        val args = paramsToArgs(request.params)
        
        try {
            // Call the method
            val result = service.handleCall(methodName, args)
            
            // Send success response
            val response = NativeRPCResponse.success(request.id, anyToJsonElement(result))
            sendResponse(response)
        } catch (e: NativeRPCError) {
            sendError(request.id, e)
        } catch (e: Exception) {
            val rpcError = NativeRPCError.internalError(e.message)
            sendError(request.id, rpcError)
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
    private fun handleSubscribe(request: NativeRPCSubscribeRequest) {
        val serviceName = request.service
        val eventName = request.eventName
        val fullEventName = request.event
        
        // Get the service (creates if needed)
        val service: NativeRPCService
        try {
            service = getService(serviceName)
        } catch (e: NativeRPCError) {
            sendError(request.id, e)
            return
        } catch (e: Exception) {
            sendError(request.id, NativeRPCError.internalError(e.message))
            return
        }
        
        // Validate event is declared
        if (!service.definitionContainer.hasEvent(eventName)) {
            val error = NativeRPCError.eventNotDeclared(eventName, serviceName)
            sendError(request.id, error)
            return
        }
        
        // Increment subscription count
        val currentCount = subscriptions.getOrDefault(fullEventName, 0)
        val isFirstSubscriber = currentCount == 0
        subscriptions[fullEventName] = currentCount + 1
        
        // Notify service if this is the first subscriber
        if (isFirstSubscriber) {
            service.onStartObserving(eventName)
        }
        
        // Send success response
        val response = NativeRPCResponse.success(request.id, JsonPrimitive(true))
        sendResponse(response)
    }
    
    /**
     * Handle an unsubscribe request
     */
    private fun handleUnsubscribe(request: NativeRPCUnsubscribeRequest) {
        val serviceName = request.service
        val eventName = request.eventName
        val fullEventName = request.event
        
        // Decrement subscription count
        val currentCount = subscriptions.getOrDefault(fullEventName, 0)
        val newCount = maxOf(0, currentCount - 1)
        subscriptions[fullEventName] = newCount
        
        val noMoreSubscribers = newCount == 0
        
        // Notify service if no more subscribers
        if (noMoreSubscribers) {
            services[serviceName]?.onStopObserving(eventName)
        }
        
        // Send success response
        val response = NativeRPCResponse.success(request.id, JsonPrimitive(true))
        sendResponse(response)
    }
    
    // MARK: - Event Sending
    
    /**
     * Send an event notification to the client
     *
     * This is called by services via `NativeRPCService.emit()`.
     * The event is only sent if the client has subscribed to it.
     *
     * @param notification The event notification to send
     */
    fun sendEvent(notification: NativeRPCNotification) {
        val eventFullName = notification.method
        
        // Check if client is subscribed to this event
        val count = subscriptions.getOrDefault(eventFullName, 0)
        if (count <= 0) return
        
        // Encode and send
        val data = try {
            json.encodeToString(NativeRPCNotification.serializer(), notification)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode notification: $eventFullName")
            return
        }
        
        delegate?.sendMessage(data)
    }
    
    /**
     * Convenience method to send event with service, event name, and params
     */
    fun sendEvent(service: String, event: String, params: JsonElement? = null) {
        val notification = NativeRPCNotification.create(service, event, params)
        sendEvent(notification)
    }
    
    // MARK: - Response Helpers
    
    private fun sendResponse(response: NativeRPCResponse) {
        val data = try {
            json.encodeToString(NativeRPCResponse.serializer(), response)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode response")
            return
        }
        delegate?.sendMessage(data)
    }
    
    private fun sendError(id: String, error: NativeRPCError) {
        val response = NativeRPCErrorResponse.from(id, error)
        val data = try {
            json.encodeToString(NativeRPCErrorResponse.serializer(), response)
        } catch (e: Exception) {
            println("[NativeRPC] Failed to encode error response")
            return
        }
        delegate?.sendMessage(data)
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
     * Shutdown the stub and destroy all service instances
     *
     * Call this when the connection closes.
     */
    fun shutdown() {
        // Cancel coroutine scope
        scope.cancel()
        
        // Destroy all services
        servicesLock.write {
            for ((name, service) in services) {
                service.destroy()
                println("[NativeRPC] Destroyed service: $name")
            }
            services.clear()
        }
        
        // Clear subscriptions
        subscriptions.clear()
        
        // Clear context storage
        context.clearStorage()
        
        println("[NativeRPC] Stub shutdown complete")
    }
    
    // MARK: - Introspection
    
    /**
     * Get list of instantiated service names for this connection
     */
    fun getActiveServiceNames(): List<String> {
        return services.keys.toList().sorted()
    }
    
    /**
     * Get list of active subscriptions for this connection
     */
    fun getActiveSubscriptions(): List<String> {
        return subscriptions.filter { it.value > 0 }.keys.toList().sorted()
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
