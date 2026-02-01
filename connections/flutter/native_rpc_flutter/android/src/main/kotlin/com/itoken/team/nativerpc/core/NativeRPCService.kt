// NativeRPCService.kt
// NativeRPC v2
//
// Base class for all NativeRPC services

package com.itoken.team.nativerpc.core

import com.itoken.team.nativerpc.dsl.LifecycleType
import com.itoken.team.nativerpc.dsl.ServiceDefinitionContainer
import com.itoken.team.nativerpc.dsl.serviceDefinition

/**
 * Interface for the RPC host that manages services
 */
interface NativeRPCHostProtocol {
    /**
     * Send an event to all subscribers
     */
    fun sendEvent(event: NativeRPCEvent)
    
    /**
     * Get a registered service by name
     */
    fun getService(name: String): NativeRPCService?
}

/**
 * Base class for NativeRPC services.
 *
 * Subclass this and override `definition()` to define your service using the DSL:
 *
 * ```kotlin
 * class MyService : NativeRPCService() {
 *     override fun definition() = serviceDefinition {
 *         Name("myService")
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
 * ```
 */
abstract class NativeRPCService {
    
    /**
     * Weak reference to the host
     */
    var host: NativeRPCHostProtocol? = null
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
     * Called when the service is registered with a host
     */
    open fun onRegistered(host: NativeRPCHostProtocol) {
        this.host = host
        definitionContainer.triggerLifecycle(LifecycleType.CREATE)
    }
    
    /**
     * Called when the service is being destroyed
     */
    fun destroy() {
        definitionContainer.triggerLifecycle(LifecycleType.DESTROY)
        host = null
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
        
        val event = NativeRPCEvent(
            service = name,
            event = eventName,
            data = data?.let { JsonElementConverter.toJsonElement(it) }
        )
        host?.sendEvent(event)
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
