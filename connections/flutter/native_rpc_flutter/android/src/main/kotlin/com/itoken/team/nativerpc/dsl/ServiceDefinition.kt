// ServiceDefinition.kt
// NativeRPC v2
//
// DSL definitions for service construction

package com.itoken.team.nativerpc.dsl

import com.itoken.team.nativerpc.core.NativeRPCError

/**
 * Marker interface for all definition elements
 */
interface ServiceDefinitionElement

/**
 * Lifecycle event types
 */
enum class LifecycleType {
    CREATE,
    DESTROY,
    APP_ENTERS_FOREGROUND,
    APP_ENTERS_BACKGROUND
}

/**
 * Event observing types
 */
enum class EventObservingType {
    START_OBSERVING,
    STOP_OBSERVING
}

// MARK: - Function Definitions

/**
 * Type-erased interface for sync functions
 */
interface SyncFunction : ServiceDefinitionElement {
    val name: String
    val argumentsCount: Int
    fun call(args: List<Any?>): Any?
}

/**
 * Type-erased interface for async functions (suspending)
 */
interface AsyncFunction : ServiceDefinitionElement {
    val name: String
    val argumentsCount: Int
    suspend fun call(args: List<Any?>): Any?
}

/**
 * Synchronous function definition
 */
class SyncFunctionDefinition<R>(
    override val name: String,
    override val argumentsCount: Int,
    private val body: (List<Any?>) -> R
) : SyncFunction {
    override fun call(args: List<Any?>): Any? {
        return body(args)
    }
}

/**
 * Asynchronous (suspending) function definition
 */
class AsyncFunctionDefinition<R>(
    override val name: String,
    override val argumentsCount: Int,
    private val body: suspend (List<Any?>) -> R
) : AsyncFunction {
    override suspend fun call(args: List<Any?>): Any? {
        return body(args)
    }
}

// MARK: - Other Definitions

/**
 * Service name definition
 */
data class ServiceNameDefinition(
    val name: String
) : ServiceDefinitionElement

/**
 * Constant definition
 */
data class ConstantDefinition(
    val name: String,
    val valueProvider: () -> Any?
) : ServiceDefinitionElement

/**
 * Events definition
 */
data class EventsDefinition(
    val names: List<String>
) : ServiceDefinitionElement

/**
 * Event observing callback definition
 */
data class EventObservingDefinition(
    val type: EventObservingType,
    val event: String?,  // null means all events
    val body: () -> Unit
) : ServiceDefinitionElement

/**
 * Lifecycle callback definition
 */
data class LifecycleDefinition(
    val type: LifecycleType,
    val body: () -> Unit
) : ServiceDefinitionElement

// MARK: - Service Definition Container

/**
 * Runtime container that stores all definitions for a service
 */
class ServiceDefinitionContainer {
    
    var serviceName: String = ""
        private set
    
    private val syncFunctions = mutableMapOf<String, SyncFunction>()
    private val asyncFunctions = mutableMapOf<String, AsyncFunction>()
    private val constants = mutableMapOf<String, () -> Any?>()
    private val eventNames = mutableSetOf<String>()
    private val startObservingCallbacks = mutableMapOf<String?, MutableList<() -> Unit>>()
    private val stopObservingCallbacks = mutableMapOf<String?, MutableList<() -> Unit>>()
    private val lifecycleCallbacks = mutableMapOf<LifecycleType, MutableList<() -> Unit>>()
    
    /**
     * Register a definition element
     */
    fun register(element: ServiceDefinitionElement) {
        when (element) {
            is ServiceNameDefinition -> {
                serviceName = element.name
            }
            is SyncFunction -> {
                syncFunctions[element.name] = element
            }
            is AsyncFunction -> {
                asyncFunctions[element.name] = element
            }
            is ConstantDefinition -> {
                constants[element.name] = element.valueProvider
            }
            is EventsDefinition -> {
                eventNames.addAll(element.names)
            }
            is EventObservingDefinition -> {
                val map = when (element.type) {
                    EventObservingType.START_OBSERVING -> startObservingCallbacks
                    EventObservingType.STOP_OBSERVING -> stopObservingCallbacks
                }
                map.getOrPut(element.event) { mutableListOf() }.add(element.body)
            }
            is LifecycleDefinition -> {
                lifecycleCallbacks.getOrPut(element.type) { mutableListOf() }.add(element.body)
            }
        }
    }
    
    // MARK: - Method Handling
    
    fun canHandle(method: String): Boolean {
        return syncFunctions.containsKey(method) || asyncFunctions.containsKey(method)
    }
    
    fun isAsync(method: String): Boolean {
        return asyncFunctions.containsKey(method)
    }
    
    suspend fun call(method: String, args: List<Any?>): Any? {
        asyncFunctions[method]?.let { return it.call(args) }
        syncFunctions[method]?.let { return it.call(args) }
        throw NativeRPCError.methodNotFound(method, serviceName)
    }
    
    // MARK: - Constants
    
    fun getConstants(): Map<String, Any?> {
        return constants.mapValues { it.value() }
    }
    
    fun getConstant(name: String): Any? {
        return constants[name]?.invoke()
    }
    
    // MARK: - Events
    
    fun getEventNames(): Set<String> = eventNames.toSet()
    
    fun hasEvent(name: String): Boolean = eventNames.contains(name)
    
    fun startObserving(event: String? = null) {
        // Global callbacks
        startObservingCallbacks[null]?.forEach { it() }
        // Event-specific callbacks
        if (event != null) {
            startObservingCallbacks[event]?.forEach { it() }
        }
    }
    
    fun stopObserving(event: String? = null) {
        stopObservingCallbacks[null]?.forEach { it() }
        if (event != null) {
            stopObservingCallbacks[event]?.forEach { it() }
        }
    }
    
    // MARK: - Lifecycle
    
    fun triggerLifecycle(type: LifecycleType) {
        lifecycleCallbacks[type]?.forEach { it() }
    }
    
    fun getMethodNames(): List<String> {
        return (syncFunctions.keys + asyncFunctions.keys).distinct()
    }
}
