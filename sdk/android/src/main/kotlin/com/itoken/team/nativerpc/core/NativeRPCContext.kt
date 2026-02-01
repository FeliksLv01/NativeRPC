// NativeRPCContext.kt
// NativeRPC v2
//
// Connection-scoped context that holds configuration and shared state.
// Services can access connection info and store custom data here.

package com.itoken.team.nativerpc.core

import android.app.Activity
import android.view.View
import java.lang.ref.WeakReference
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

/**
 * Represents the type of connection used for RPC communication
 */
enum class NativeRPCConnectionType(val value: String) {
    /** Flutter MethodChannel connection */
    FLUTTER("flutter"),
    /** WebView JavaScript bridge connection */
    WEB_VIEW("webView"),
    /** WebSocket connection */
    WEB_SOCKET("webSocket"),
    /** React Native bridge connection */
    REACT_NATIVE("reactNative"),
    /** Custom connection type */
    CUSTOM("custom")
}

/**
 * A context object that holds configuration and state for a specific RPC connection.
 *
 * Each connection has its own context, and all services created for that connection
 * share the same context. Services can use the context to:
 * - Access connection information (type)
 * - Store and retrieve custom data (shared across services)
 * - Access platform-specific views/activities
 *
 * Example usage in a service:
 * ```kotlin
 * class UserService : NativeRPCService() {
 *     fun someMethod() {
 *         // Store data for other services to access
 *         context?.set("currentUserId", "user123")
 *
 *         // Read data stored by other services
 *         val theme: String? = context?.get("appTheme")
 *     }
 * }
 * ```
 */
class NativeRPCContext(
    /** The type of connection this context belongs to */
    val connectionType: NativeRPCConnectionType,
    /** Custom connection type name (only used when connectionType == CUSTOM) */
    val customConnectionTypeName: String? = null,
    /** The root view associated with this context */
    rootView: View? = null,
    /** The activity associated with this context */
    activity: Activity? = null
) {
    
    // MARK: - Properties
    
    /** Weak reference to the root view (to avoid memory leaks) */
    private val _rootView: WeakReference<View>? = rootView?.let { WeakReference(it) }
    
    /** Weak reference to the activity (to avoid memory leaks) */
    private val _activity: WeakReference<Activity>? = activity?.let { WeakReference(it) }
    
    /** The root view associated with this context */
    val rootView: View? get() = _rootView?.get()
    
    /** The activity associated with this context */
    val activity: Activity? get() = _activity?.get()
    
    /** Custom storage for services to share data */
    private val storage = mutableMapOf<String, Any?>()
    
    /** Read-write lock for thread-safe storage access (faster than synchronized for read-heavy workloads) */
    private val rwLock = ReentrantReadWriteLock()
    
    // MARK: - Storage API
    
    /**
     * Store a value in the context's shared storage
     *
     * @param key The key to store the value under
     * @param value The value to store
     *
     * Example:
     * ```kotlin
     * context.set("userId", "user123")
     * context.set("preferences", mapOf("theme" to "dark"))
     * ```
     */
    fun set(key: String, value: Any?) {
        rwLock.write {
            storage[key] = value
        }
    }
    
    /**
     * Retrieve a value from the context's shared storage
     *
     * @param key The key to look up
     * @return The value if it exists and can be cast to the expected type, null otherwise
     *
     * Example:
     * ```kotlin
     * val userId: String? = context.get("userId")
     * val preferences: Map<String, Any>? = context.get("preferences")
     * ```
     */
    @Suppress("UNCHECKED_CAST")
    fun <T> get(key: String): T? {
        return rwLock.read {
            storage[key] as? T
        }
    }
    
    /**
     * Remove a value from the context's shared storage
     *
     * @param key The key to remove
     * @return The removed value if it existed, null otherwise
     */
    @Suppress("UNCHECKED_CAST")
    fun <T> remove(key: String): T? {
        return rwLock.write {
            storage.remove(key) as? T
        }
    }
    
    /**
     * Check if a key exists in the storage
     *
     * @param key The key to check
     * @return true if the key exists, false otherwise
     */
    fun contains(key: String): Boolean {
        return rwLock.read {
            storage.containsKey(key)
        }
    }
    
    /**
     * Clear all stored values
     */
    fun clearStorage() {
        rwLock.write {
            storage.clear()
        }
    }
    
    // MARK: - Convenience
    
    /**
     * Get the connection type as a descriptive string
     */
    val connectionTypeDescription: String
        get() = if (connectionType == NativeRPCConnectionType.CUSTOM && customConnectionTypeName != null) {
            customConnectionTypeName
        } else {
            connectionType.value
        }
}
