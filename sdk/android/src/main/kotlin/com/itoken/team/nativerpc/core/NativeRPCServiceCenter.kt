// NativeRPCServiceCenter.kt
// NativeRPC v2
//
// Global singleton that stores service types/factories.
// Services are registered here by type, then instantiated per-connection by NativeRPCStub.

package com.itoken.team.nativerpc.core

import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write
import kotlin.reflect.KClass

/**
 * Interface for service types that can be instantiated by the service center.
 * Services must provide a factory function that creates instances with a context.
 */
interface NativeRPCServiceFactory<T : NativeRPCService> {
    /** The unique name identifying this service (e.g., "counter", "user") */
    val serviceName: String
    
    /** Connection types this service supports (defaults to all) */
    val supportedConnectionTypes: Set<NativeRPCConnectionType>
        get() = setOf(
            NativeRPCConnectionType.FLUTTER,
            NativeRPCConnectionType.WEB_VIEW,
            NativeRPCConnectionType.WEB_SOCKET,
            NativeRPCConnectionType.REACT_NATIVE,
            NativeRPCConnectionType.CUSTOM
        )
    
    /** Create a new instance of this service with the given context */
    fun create(context: NativeRPCContext?): T
}

/**
 * Internal storage for a registered service factory
 */
private data class ServiceRegistration(
    val factory: NativeRPCServiceFactory<*>,
    val supportedConnectionTypes: Set<NativeRPCConnectionType>
)

/**
 * Global singleton that stores service factories.
 *
 * Services are registered here by factory (not instance), then instantiated
 * per-connection by `NativeRPCStub` when first needed.
 *
 * Usage:
 * ```kotlin
 * // At app startup - register service factories
 * NativeRPCServiceCenter.register(CounterService.Factory)
 * NativeRPCServiceCenter.register(UserService.Factory)
 *
 * // Services are instantiated per-connection when first called
 * // (handled automatically by NativeRPCStub)
 * ```
 *
 * Alternative: Register with lambda factory
 * ```kotlin
 * NativeRPCServiceCenter.register("counter") { context ->
 *     CounterService(context)
 * }
 * ```
 */
object NativeRPCServiceCenter {
    
    // MARK: - Properties
    
    /** Registered service factories by name */
    private val registrations = mutableMapOf<String, ServiceRegistration>()
    
    /** Read-write lock for thread-safe access (faster than synchronized for read-heavy workloads) */
    private val rwLock = ReentrantReadWriteLock()
    
    // MARK: - Registration
    
    /**
     * Register a service factory with the service center.
     *
     * @param factory The service factory to register
     *
     * Example:
     * ```kotlin
     * NativeRPCServiceCenter.register(CounterService.Factory)
     * ```
     */
    fun <T : NativeRPCService> register(factory: NativeRPCServiceFactory<T>) {
        rwLock.write {
            val name = factory.serviceName
            
            if (registrations.containsKey(name)) {
                println("[NativeRPC] Warning: Service '$name' is already registered, replacing...")
            }
            
            registrations[name] = ServiceRegistration(
                factory = factory,
                supportedConnectionTypes = factory.supportedConnectionTypes
            )
            
            println("[NativeRPC] Registered service type: $name")
        }
    }
    
    /**
     * Register a service with a lambda factory.
     *
     * @param serviceName The unique name for this service
     * @param supportedConnectionTypes Connection types this service supports
     * @param factory Lambda that creates service instances
     *
     * Example:
     * ```kotlin
     * NativeRPCServiceCenter.register("counter") { context ->
     *     CounterService(context)
     * }
     * ```
     */
    fun <T : NativeRPCService> register(
        serviceName: String,
        supportedConnectionTypes: Set<NativeRPCConnectionType> = setOf(
            NativeRPCConnectionType.FLUTTER,
            NativeRPCConnectionType.WEB_VIEW,
            NativeRPCConnectionType.WEB_SOCKET,
            NativeRPCConnectionType.REACT_NATIVE,
            NativeRPCConnectionType.CUSTOM
        ),
        factory: (NativeRPCContext?) -> T
    ) {
        register(object : NativeRPCServiceFactory<T> {
            override val serviceName: String = serviceName
            override val supportedConnectionTypes: Set<NativeRPCConnectionType> = supportedConnectionTypes
            override fun create(context: NativeRPCContext?): T = factory(context)
        })
    }
    
    /**
     * Register multiple service factories at once
     */
    fun register(vararg factories: NativeRPCServiceFactory<*>) {
        for (factory in factories) {
            register(factory)
        }
    }
    
    /**
     * Unregister a service by name
     *
     * @param name The service name to unregister
     */
    fun unregister(name: String) {
        rwLock.write {
            if (registrations.remove(name) != null) {
                println("[NativeRPC] Unregistered service type: $name")
            }
        }
    }
    
    // MARK: - Service Lookup (Internal)
    
    /**
     * Get the service factory for a given name.
     * This is called by `NativeRPCStub` to instantiate services.
     *
     * @param name The service name
     * @return The service factory if registered, null otherwise
     */
    internal fun getFactory(name: String): NativeRPCServiceFactory<*>? {
        return rwLock.read {
            registrations[name]?.factory
        }
    }
    
    /**
     * Check if a service supports a given connection type
     *
     * @param serviceName The service name
     * @param connectionType The connection type to check
     * @return true if the service supports the connection type
     */
    internal fun supportsConnectionType(serviceName: String, connectionType: NativeRPCConnectionType): Boolean {
        return rwLock.read {
            registrations[serviceName]?.supportedConnectionTypes?.contains(connectionType) ?: false
        }
    }
    
    // MARK: - Introspection
    
    /**
     * Get list of all registered service names
     */
    fun getRegisteredServiceNames(): List<String> {
        return rwLock.read {
            registrations.keys.toList().sorted()
        }
    }
    
    /**
     * Check if a service is registered
     *
     * @param name The service name to check
     * @return true if the service is registered
     */
    fun isRegistered(name: String): Boolean {
        return rwLock.read {
            registrations.containsKey(name)
        }
    }
    
    // MARK: - Reset (for testing)
    
    /**
     * Remove all registered services. Primarily for testing.
     */
    fun reset() {
        rwLock.write {
            registrations.clear()
            println("[NativeRPC] Service center reset")
        }
    }
}
