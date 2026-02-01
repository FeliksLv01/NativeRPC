// ServiceDefinitionBuilder.kt
// NativeRPC v2
//
// DSL builder for service definitions

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
 * class MyService : NativeRPCService() {
 *     override fun definition() = serviceDefinition {
 *         Name("myService")
 *
 *         Constant("version") { "1.0.0" }
 *
 *         Function("add") { args: List<Any?> ->
 *             val a = args[0] as Int
 *             val b = args[1] as Int
 *             a + b
 *         }
 *
 *         AsyncFunction("fetchData") { args: List<Any?> ->
 *             val id = args[0] as String
 *             repository.fetch(id)
 *         }
 *
 *         Events("dataChanged", "statusUpdated")
 *     }
 * }
 * ```
 */
@NativeRPCDsl
class ServiceDefinitionBuilder {
    
    private val container = ServiceDefinitionContainer()
    
    // MARK: - Name
    
    /**
     * Set the service name
     */
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
    
    // MARK: - Sync Functions
    
    /**
     * Define a synchronous function with raw args list
     */
    fun <R> Function(name: String, body: (List<Any?>) -> R) {
        container.register(SyncFunctionDefinition(name, -1, body))
    }
    
    /**
     * Define a synchronous function with no arguments
     */
    fun <R> Function0(name: String, body: () -> R) {
        container.register(SyncFunctionDefinition<R>(name, 0) { _ -> body() })
    }
    
    /**
     * Define a synchronous function with 1 argument
     */
    inline fun <reified A, R> Function1(name: String, crossinline body: (A) -> R) {
        container.register(SyncFunctionDefinition<R>(name, 1) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A)
        })
    }
    
    /**
     * Define a synchronous function with 2 arguments
     */
    inline fun <reified A, reified B, R> Function2(name: String, crossinline body: (A, B) -> R) {
        container.register(SyncFunctionDefinition<R>(name, 2) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B)
        })
    }
    
    /**
     * Define a synchronous function with 3 arguments
     */
    inline fun <reified A, reified B, reified C, R> Function3(
        name: String,
        crossinline body: (A, B, C) -> R
    ) {
        container.register(SyncFunctionDefinition<R>(name, 3) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B, args[2] as C)
        })
    }
    
    /**
     * Define a synchronous function with 4 arguments
     */
    inline fun <reified A, reified B, reified C, reified D, R> Function4(
        name: String,
        crossinline body: (A, B, C, D) -> R
    ) {
        container.register(SyncFunctionDefinition<R>(name, 4) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B, args[2] as C, args[3] as D)
        })
    }
    
    /**
     * Define a synchronous function with 5 arguments
     */
    inline fun <reified A, reified B, reified C, reified D, reified E, R> Function5(
        name: String,
        crossinline body: (A, B, C, D, E) -> R
    ) {
        container.register(SyncFunctionDefinition<R>(name, 5) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B, args[2] as C, args[3] as D, args[4] as E)
        })
    }
    
    // MARK: - Async Functions
    
    /**
     * Define an asynchronous (suspending) function with raw args list
     */
    fun <R> AsyncFunction(name: String, body: suspend (List<Any?>) -> R) {
        container.register(AsyncFunctionDefinition(name, -1, body))
    }
    
    /**
     * Define an asynchronous function with no arguments
     */
    fun <R> AsyncFunction0(name: String, body: suspend () -> R) {
        container.register(AsyncFunctionDefinition<R>(name, 0) { _ -> body() })
    }
    
    /**
     * Define an asynchronous function with 1 argument
     */
    inline fun <reified A, R> AsyncFunction1(name: String, crossinline body: suspend (A) -> R) {
        container.register(AsyncFunctionDefinition<R>(name, 1) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A)
        })
    }
    
    /**
     * Define an asynchronous function with 2 arguments
     */
    inline fun <reified A, reified B, R> AsyncFunction2(
        name: String,
        crossinline body: suspend (A, B) -> R
    ) {
        container.register(AsyncFunctionDefinition<R>(name, 2) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B)
        })
    }
    
    /**
     * Define an asynchronous function with 3 arguments
     */
    inline fun <reified A, reified B, reified C, R> AsyncFunction3(
        name: String,
        crossinline body: suspend (A, B, C) -> R
    ) {
        container.register(AsyncFunctionDefinition<R>(name, 3) { args ->
            @Suppress("UNCHECKED_CAST")
            body(args[0] as A, args[1] as B, args[2] as C)
        })
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
