// NativeRPCService.kt
// NativeRPC v2
//
// Base class for all NativeRPC services

package com.itoken.team.nativerpc.core

import com.itoken.team.nativerpc.dsl.LifecycleType
import com.itoken.team.nativerpc.dsl.ServiceDefinitionContainer
import com.itoken.team.nativerpc.dsl.serviceDefinition

/**
 * Base class for NativeRPC services.
 *
 * Subclass this and override `definition()` to define your service using the DSL.
 *
 * ## New Architecture (v2.1)
 *
 * Services are now:
 * - **Registered by factory** at app startup via `NativeRPCServiceCenter`
 * - **Instantiated per-connection** when first called
 * - **Destroyed** when the connection closes
 *
 * ```kotlin
 * class MyService(context: NativeRPCContext?) : NativeRPCService() {
 *     
 *     // Define the factory for registration
 *     companion object {
 *         val Factory = object : NativeRPCServiceFactory<MyService> {
 *             override val serviceName = "myService"
 *             override fun create(context: NativeRPCContext?) = MyService(context)
 *         }
 *     }
 *     
 *     override fun definition() = serviceDefinition {
 *         // Name() is optional - auto-inferred from Factory.serviceName
 *
 *         Constant("version") { "1.0.0" }
 *
 *         Function2<Int, Int, Int>("add") { a, b -> a + b }
 *
 *         AsyncFunction1<String, User>("fetchUser") { id ->
 *             userRepository.fetch(id)
 *         }
 *
 *         Events("userChanged", "configUpdated")
 *     }
 * }
 *
 * // Register at app startup
 * NativeRPCServiceCenter.register(MyService.Factory)
 *
 * // Or use lambda registration
 * NativeRPCServiceCenter.register("myService") { context ->
 *     MyService(context)
 * }
 * ```
 */
abstract class NativeRPCService {
    
    // MARK: - Instance Properties
    
    /**
     * The context for this connection (contains connection info and shared storage).
     * Set internally when the service is created by the stub.
     */
    var internalContext: NativeRPCContext? = null
        internal set
    
    /**
     * The context for this connection.
     * Use this to access connection-scoped state.
     */
    val context: NativeRPCContext?
        get() = internalContext
    
    /**
     * Weak reference to the stub that owns this service.
     * Set internally when the service is created by the stub.
     */
    var stub: NativeRPCStub? = null
        internal set
    
    /**
     * Cached service definition container
     */
    private var _definitionContainer: ServiceDefinitionContainer? = null
    
    /**
     * Get or build the definition container
     */
    val definitionContainer: ServiceDefinitionContainer
        get() {
            if (_definitionContainer == null) {
                _definitionContainer = definition()
                _definitionContainer?.triggerLifecycle(LifecycleType.CREATE)
            }
            return _definitionContainer!!
        }
    
    /**
     * The service name (from definition)
     */
    val name: String
        get() = definitionContainer.serviceName
    
    /**
     * Override this method to define your service using the DSL.
     */
    abstract fun definition(): ServiceDefinitionContainer
    
    // MARK: - Lifecycle
    
    /**
     * Called when the service is being destroyed
     */
    fun destroy() {
        definitionContainer.triggerLifecycle(LifecycleType.DESTROY)
        stub = null
    }
    
    /**
     * Called when the app enters foreground
     */
    fun onForeground() {
        definitionContainer.triggerLifecycle(LifecycleType.APP_ENTERS_FOREGROUND)
    }
    
    /**
     * Called when the app enters background
     */
    fun onBackground() {
        definitionContainer.triggerLifecycle(LifecycleType.APP_ENTERS_BACKGROUND)
    }
    
    // MARK: - Event Sending
    
    /**
     * Send an event to all subscribers.
     *
     * @param eventName The event name (must be declared in `Events()`)
     * @param data Optional event data
     * @throws NativeRPCError if event name not declared
     */
    @Throws(NativeRPCError::class)
    fun sendEvent(eventName: String, data: Any? = null) {
        if (!definitionContainer.hasEvent(eventName)) {
            throw NativeRPCError.eventNotDeclared(eventName, name)
        }
        
        val stubRef = stub
        if (stubRef == null) {
            println("[NativeRPC] Warning: Cannot send event '$eventName' - service not attached to stub")
            return
        }
        
        val notification = NativeRPCNotification.create(
            service = name,
            event = eventName,
            params = data?.let { JsonElementConverter.toJsonElement(it) }
        )
        stubRef.sendEvent(notification)
    }
    
    /**
     * Send an event without throwing (logs error if event not declared)
     */
    fun emit(eventName: String, data: Any? = null) {
        try {
            sendEvent(eventName, data)
        } catch (e: Exception) {
            println("[NativeRPC] Error sending event '$eventName': ${e.message}")
        }
    }
    
    // MARK: - Method Handling
    
    /**
     * Handle an incoming RPC call
     */
    suspend fun handleCall(method: String, args: List<Any?>): Any? {
        return definitionContainer.call(method, args)
    }
    
    /**
     * Check if this service can handle a method
     */
    fun canHandle(method: String): Boolean {
        return definitionContainer.canHandle(method)
    }
    
    // MARK: - Constants
    
    /**
     * Get all constants as a map
     */
    fun getConstants(): Map<String, Any?> {
        return definitionContainer.getConstants()
    }
    
    // MARK: - Subscription Handling
    
    /**
     * Called when a client starts observing events
     */
    fun onStartObserving(event: String? = null) {
        definitionContainer.startObserving(event)
    }
    
    /**
     * Called when a client stops observing events
     */
    fun onStopObserving(event: String? = null) {
        definitionContainer.stopObserving(event)
    }
    
    // MARK: - Context Convenience
    
    /**
     * Get the connection type (convenience accessor)
     */
    val connectionType: NativeRPCConnectionType?
        get() = context?.connectionType
}

/**
 * Helper for converting Any to JsonElement
 */
internal object JsonElementConverter {
    fun toJsonElement(value: Any?): kotlinx.serialization.json.JsonElement? {
        if (value == null) return null
        
        return when (value) {
            is String -> kotlinx.serialization.json.JsonPrimitive(value)
            is Number -> kotlinx.serialization.json.JsonPrimitive(value)
            is Boolean -> kotlinx.serialization.json.JsonPrimitive(value)
            is Map<*, *> -> {
                val map = value.entries.associate { 
                    (it.key as String) to toJsonElement(it.value) 
                }.filterValues { it != null }.mapValues { it.value!! }
                kotlinx.serialization.json.JsonObject(map)
            }
            is List<*> -> {
                val list = value.mapNotNull { toJsonElement(it) }
                kotlinx.serialization.json.JsonArray(list)
            }
            else -> kotlinx.serialization.json.JsonPrimitive(value.toString())
        }
    }
}
