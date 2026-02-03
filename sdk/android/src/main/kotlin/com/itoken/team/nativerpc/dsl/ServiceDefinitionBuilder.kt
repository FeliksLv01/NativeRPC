// ServiceDefinitionBuilder.kt
// NativeRPC v2.2
//
// DSL builder for service definitions with Codable-style params

package com.itoken.team.nativerpc.dsl

/**
 * DSL marker to prevent scope leakage
 */
@DslMarker
annotation class NativeRPCDsl

/**
 * Builder class for constructing service definitions using Kotlin DSL.
 *
 * Example usage:
 * ```kotlin
 * // Define params data classes
 * data class AddParams(val value: Int)
 * data class AddTwoParams(val a: Int, val b: Int)
 *
 * class MyService : NativeRPCService() {
 *     override fun definition() = serviceDefinition {
 *         // Name() is optional - auto-inferred from Factory.serviceName
 *
 *         Constant("version") { "1.0.0" }
 *
 *         // No params - use Function without params type
 *         Function<Int>("getValue") {
 *             count
 *         }
 *
 *         // With params - use Function with params type
 *         Function<AddParams, Int>("add") { params ->
 *             count += params.value
 *             count
 *         }
 *
 *         // Multiple params bundled in one data class
 *         Function<AddTwoParams, Int>("addTwo") { params ->
 *             count += params.a + params.b
 *             count
 *         }
 *
 *         // Async functions work the same way
 *         AsyncFunction<Int>("getValueAsync") {
 *             delay(100)
 *             count
 *         }
 *
 *         Events("dataChanged", "statusUpdated")
 *     }
 * }
 * ```
 */
@NativeRPCDsl
class ServiceDefinitionBuilder {
    
    @PublishedApi
    internal val container = ServiceDefinitionContainer()
    
    // MARK: - Name
    
    /**
     * Set the service name
     *
     * **Deprecated in v2.2** - Service name is now automatically set from the
     * Factory's serviceName. You no longer need to call Name() in your definition.
     *
     * ```kotlin
     * // Before (deprecated):
     * override fun definition() = serviceDefinition {
     *     Name("counter")  // ❌ No longer needed
     *     Function<Int>("getValue") { ... }
     * }
     *
     * // After:
     * companion object {
     *     val Factory = object : NativeRPCServiceFactory<MyService> {
     *         override val serviceName = "counter"  // ✅ Define here
     *         ...
     *     }
     * }
     * override fun definition() = serviceDefinition {
     *     Function<Int>("getValue") { ... }  // Name is auto-set from Factory
     * }
     * ```
     */
    @Deprecated(
        message = "Name() is no longer needed. Service name is automatically set from Factory.serviceName.",
        level = DeprecationLevel.WARNING
    )
    fun Name(name: String) {
        container.register(ServiceNameDefinition(name))
    }
    
    // MARK: - Constants
    
    /**
     * Define a constant
     */
    fun Constant(name: String, valueProvider: () -> Any?) {
        container.register(ConstantDefinition(name, valueProvider))
    }
    
    // MARK: - Sync Functions (New Codable-style API)
    
    /**
     * Define a synchronous function with no parameters.
     *
     * ```kotlin
     * Function<Int>("getValue") {
     *     count
     * }
     * ```
     */
    inline fun <reified R : Any> Function(name: String, noinline body: () -> R) {
        container.register(SyncFunctionDefinition(
            name = name,
            argumentsCount = 0,
            paramsClass = VoidParams::class.java,
            body = { _ -> body() }
        ))
    }
    
    /**
     * Define a synchronous function with Codable-style params.
     *
     * ```kotlin
     * data class AddParams(val value: Int)
     *
     * Function<AddParams, Int>("add") { params ->
     *     count += params.value
     *     count
     * }
     * ```
     */
    inline fun <reified Params : Any, reified R : Any> Function(
        name: String,
        noinline body: (Params) -> R
    ) {
        container.register(SyncFunctionDefinition(
            name = name,
            argumentsCount = 1,
            paramsClass = Params::class.java,
            body = body
        ))
    }
    
    // MARK: - Async Functions (New Codable-style API)
    
    /**
     * Define an asynchronous (suspending) function with no parameters.
     *
     * ```kotlin
     * AsyncFunction<Int>("getValueAsync") {
     *     delay(100)
     *     count
     * }
     * ```
     */
    inline fun <reified R : Any> AsyncFunction(name: String, noinline body: suspend () -> R) {
        container.register(AsyncFunctionDefinition(
            name = name,
            argumentsCount = 0,
            paramsClass = VoidParams::class.java,
            body = { _ -> body() }
        ))
    }
    
    /**
     * Define an asynchronous (suspending) function with Codable-style params.
     *
     * ```kotlin
     * data class DelayParams(val delayMs: Int)
     *
     * AsyncFunction<DelayParams, Int>("getValueDelayed") { params ->
     *     delay(params.delayMs.toLong())
     *     count
     * }
     * ```
     */
    inline fun <reified Params : Any, reified R : Any> AsyncFunction(
        name: String,
        noinline body: suspend (Params) -> R
    ) {
        container.register(AsyncFunctionDefinition(
            name = name,
            argumentsCount = 1,
            paramsClass = Params::class.java,
            body = body
        ))
    }
    
    // MARK: - Legacy FunctionN API (Deprecated)
    
    /**
     * @deprecated Use `Function<R>("name") { ... }` instead
     */
    @Deprecated(
        message = "Use Function<R>(\"name\") { ... } instead",
        replaceWith = ReplaceWith("Function<R>(name, body)"),
        level = DeprecationLevel.WARNING
    )
    fun <R : Any> Function0(name: String, body: () -> R) {
        Function(name, body)
    }
    
    /**
     * @deprecated Use `Function<Params, R>("name") { params -> ... }` instead
     */
    @Deprecated(
        message = "Use Function<Params, R>(\"name\") { params -> ... } instead. Define a data class for params.",
        level = DeprecationLevel.WARNING
    )
    inline fun <reified A, R : Any> Function1(name: String, crossinline body: (A) -> R) {
        // Legacy compatibility: wrap single arg as a map key
        container.register(SyncFunctionDefinition<Map<String, Any?>, R>(
            name = name,
            argumentsCount = 1,
            paramsClass = Map::class.java as Class<Map<String, Any?>>,
            body = { args ->
                @Suppress("UNCHECKED_CAST")
                val value = args.values.firstOrNull() as A
                body(value)
            }
        ))
    }
    
    /**
     * @deprecated Use `Function<Params, R>("name") { params -> ... }` instead
     */
    @Deprecated(
        message = "Use Function<Params, R>(\"name\") { params -> ... } instead. Define a data class for params.",
        level = DeprecationLevel.WARNING
    )
    inline fun <reified A, reified B, R : Any> Function2(name: String, crossinline body: (A, B) -> R) {
        container.register(SyncFunctionDefinition<Map<String, Any?>, R>(
            name = name,
            argumentsCount = 2,
            paramsClass = Map::class.java as Class<Map<String, Any?>>,
            body = { args ->
                @Suppress("UNCHECKED_CAST")
                val values = args.values.toList()
                body(values[0] as A, values[1] as B)
            }
        ))
    }
    
    /**
     * @deprecated Use `AsyncFunction<R>("name") { ... }` instead
     */
    @Deprecated(
        message = "Use AsyncFunction<R>(\"name\") { ... } instead",
        replaceWith = ReplaceWith("AsyncFunction<R>(name, body)"),
        level = DeprecationLevel.WARNING
    )
    fun <R : Any> AsyncFunction0(name: String, body: suspend () -> R) {
        AsyncFunction(name, body)
    }
    
    /**
     * @deprecated Use `AsyncFunction<Params, R>("name") { params -> ... }` instead
     */
    @Deprecated(
        message = "Use AsyncFunction<Params, R>(\"name\") { params -> ... } instead. Define a data class for params.",
        level = DeprecationLevel.WARNING
    )
    inline fun <reified A, R : Any> AsyncFunction1(name: String, crossinline body: suspend (A) -> R) {
        container.register(AsyncFunctionDefinition<Map<String, Any?>, R>(
            name = name,
            argumentsCount = 1,
            paramsClass = Map::class.java as Class<Map<String, Any?>>,
            body = { args ->
                @Suppress("UNCHECKED_CAST")
                val value = args.values.firstOrNull() as A
                body(value)
            }
        ))
    }
    
    /**
     * @deprecated Use `AsyncFunction<Params, R>("name") { params -> ... }` instead
     */
    @Deprecated(
        message = "Use AsyncFunction<Params, R>(\"name\") { params -> ... } instead. Define a data class for params.",
        level = DeprecationLevel.WARNING
    )
    inline fun <reified A, reified B, R : Any> AsyncFunction2(
        name: String,
        crossinline body: suspend (A, B) -> R
    ) {
        container.register(AsyncFunctionDefinition<Map<String, Any?>, R>(
            name = name,
            argumentsCount = 2,
            paramsClass = Map::class.java as Class<Map<String, Any?>>,
            body = { args ->
                @Suppress("UNCHECKED_CAST")
                val values = args.values.toList()
                body(values[0] as A, values[1] as B)
            }
        ))
    }
    
    // MARK: - Events
    
    /**
     * Declare events that this service can emit
     */
    fun Events(vararg names: String) {
        container.register(EventsDefinition(names.toList()))
    }
    
    // MARK: - Event Observing
    
    /**
     * Callback when client starts observing any event
     */
    fun OnStartObserving(body: () -> Unit) {
        container.register(EventObservingDefinition(EventObservingType.START_OBSERVING, null, body))
    }
    
    /**
     * Callback when client starts observing a specific event
     */
    fun OnStartObserving(event: String, body: () -> Unit) {
        container.register(EventObservingDefinition(EventObservingType.START_OBSERVING, event, body))
    }
    
    /**
     * Callback when client stops observing any event
     */
    fun OnStopObserving(body: () -> Unit) {
        container.register(EventObservingDefinition(EventObservingType.STOP_OBSERVING, null, body))
    }
    
    /**
     * Callback when client stops observing a specific event
     */
    fun OnStopObserving(event: String, body: () -> Unit) {
        container.register(EventObservingDefinition(EventObservingType.STOP_OBSERVING, event, body))
    }
    
    // MARK: - Lifecycle
    
    /**
     * Callback when service is created
     */
    fun OnCreate(body: () -> Unit) {
        container.register(LifecycleDefinition(LifecycleType.CREATE, body))
    }
    
    /**
     * Callback when service is destroyed
     */
    fun OnDestroy(body: () -> Unit) {
        container.register(LifecycleDefinition(LifecycleType.DESTROY, body))
    }
    
    /**
     * Callback when app enters foreground
     */
    fun OnAppEntersForeground(body: () -> Unit) {
        container.register(LifecycleDefinition(LifecycleType.APP_ENTERS_FOREGROUND, body))
    }
    
    /**
     * Callback when app enters background
     */
    fun OnAppEntersBackground(body: () -> Unit) {
        container.register(LifecycleDefinition(LifecycleType.APP_ENTERS_BACKGROUND, body))
    }
    
    /**
     * @deprecated Use OnAppEntersForeground instead
     */
    @Deprecated("Use OnAppEntersForeground instead", ReplaceWith("OnAppEntersForeground(body)"))
    fun OnActivityEntersForeground(body: () -> Unit) {
        OnAppEntersForeground(body)
    }
    
    /**
     * @deprecated Use OnAppEntersBackground instead
     */
    @Deprecated("Use OnAppEntersBackground instead", ReplaceWith("OnAppEntersBackground(body)"))
    fun OnActivityEntersBackground(body: () -> Unit) {
        OnAppEntersBackground(body)
    }
    
    /**
     * Build the container
     */
    fun build(): ServiceDefinitionContainer = container
}

/**
 * DSL entry point for building a service definition
 */
fun serviceDefinition(block: ServiceDefinitionBuilder.() -> Unit): ServiceDefinitionContainer {
    return ServiceDefinitionBuilder().apply(block).build()
}
