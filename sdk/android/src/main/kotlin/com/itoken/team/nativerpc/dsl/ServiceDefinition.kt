// ServiceDefinition.kt
// NativeRPC v2.2
//
// DSL definitions for service construction with Codable-style params

package com.itoken.team.nativerpc.dsl

import com.google.gson.Gson
import com.google.gson.JsonSyntaxException
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

// MARK: - VoidParams / VoidResult

/**
 * Placeholder type for functions with no parameters.
 * Used internally to satisfy type constraints when no params are needed.
 */
class VoidParams {
    companion object {
        val INSTANCE = VoidParams()
    }
}

/**
 * Placeholder type for functions that return nothing.
 * Used internally to satisfy type constraints when no result is returned.
 */
class VoidResult {
    companion object {
        val INSTANCE = VoidResult()
    }
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
 * Synchronous function definition with Codable-style params support.
 *
 * Uses Gson for JSON deserialization, allowing any data class to be used
 * as params without special annotations.
 *
 * @param Params The params type (must be a data class or VoidParams)
 * @param R The return type
 */
class SyncFunctionDefinition<Params : Any, R : Any?>(
    override val name: String,
    override val argumentsCount: Int,
    private val paramsClass: Class<Params>,
    private val body: (Params) -> R
) : SyncFunction {
    
    companion object {
        private val gson = Gson()
    }
    
    override fun call(args: List<Any?>): Any? {
        val params = decodeParams(args)
        val result = body(params)
        return encodeResult(result)
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun decodeParams(args: List<Any?>): Params {
        // VoidParams special handling - no params needed
        if (paramsClass == VoidParams::class.java) {
            return VoidParams.INSTANCE as Params
        }
        
        // Extract dictionary from args
        val dict = args.firstOrNull()
        if (dict == null || dict !is Map<*, *>) {
            throw NativeRPCError.invalidParams(
                "Expected params dictionary, got: ${dict?.javaClass?.simpleName ?: "null"}"
            )
        }
        
        // Use Gson to decode
        try {
            val json = gson.toJson(dict)
            return gson.fromJson(json, paramsClass)
        } catch (e: JsonSyntaxException) {
            throw NativeRPCError.invalidParams("Failed to decode params: ${e.message}")
        }
    }
    
    private fun encodeResult(result: R): Any? {
        // For VoidResult or Unit, return null
        if (result == null || result is VoidResult || result is Unit) {
            return null
        }
        
        // Primitive types pass through directly
        if (result is Number || result is String || result is Boolean) {
            return result
        }
        
        // Complex types are serialized to Map via Gson
        val json = gson.toJson(result)
        @Suppress("UNCHECKED_CAST")
        return gson.fromJson(json, Map::class.java)
    }
}

/**
 * Asynchronous (suspending) function definition with Codable-style params support.
 *
 * Uses Gson for JSON deserialization, allowing any data class to be used
 * as params without special annotations.
 *
 * @param Params The params type (must be a data class or VoidParams)
 * @param R The return type
 */
class AsyncFunctionDefinition<Params : Any, R : Any?>(
    override val name: String,
    override val argumentsCount: Int,
    private val paramsClass: Class<Params>,
    private val body: suspend (Params) -> R
) : AsyncFunction {
    
    companion object {
        private val gson = Gson()
    }
    
    override suspend fun call(args: List<Any?>): Any? {
        val params = decodeParams(args)
        val result = body(params)
        return encodeResult(result)
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun decodeParams(args: List<Any?>): Params {
        // VoidParams special handling - no params needed
        if (paramsClass == VoidParams::class.java) {
            return VoidParams.INSTANCE as Params
        }
        
        // Extract dictionary from args
        val dict = args.firstOrNull()
        if (dict == null || dict !is Map<*, *>) {
            throw NativeRPCError.invalidParams(
                "Expected params dictionary, got: ${dict?.javaClass?.simpleName ?: "null"}"
            )
        }
        
        // Use Gson to decode
        try {
            val json = gson.toJson(dict)
            return gson.fromJson(json, paramsClass)
        } catch (e: JsonSyntaxException) {
            throw NativeRPCError.invalidParams("Failed to decode params: ${e.message}")
        }
    }
    
    private fun encodeResult(result: R): Any? {
        // For VoidResult or Unit, return null
        if (result == null || result is VoidResult || result is Unit) {
            return null
        }
        
        // Primitive types pass through directly
        if (result is Number || result is String || result is Boolean) {
            return result
        }
        
        // Complex types are serialized to Map via Gson
        val json = gson.toJson(result)
        @Suppress("UNCHECKED_CAST")
        return gson.fromJson(json, Map::class.java)
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
    
    /**
     * Set the service name (used for auto-inference when Name() is not called)
     */
    fun setServiceName(name: String) {
        serviceName = name
    }
    
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
