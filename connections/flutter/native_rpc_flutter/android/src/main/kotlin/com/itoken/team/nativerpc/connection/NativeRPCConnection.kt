// NativeRPCConnection.kt
// NativeRPC v2
//
// Connection protocol and base implementations

package com.itoken.team.nativerpc.connection

import java.util.UUID

/**
 * Protocol for connections between native and clients (Flutter, WebView, etc.)
 */
interface NativeRPCConnection {
    
    /**
     * Unique identifier for this connection
     */
    val id: String
    
    /**
     * Callback invoked when a message is received from the client
     */
    var onMessage: ((String) -> Unit)?
    
    /**
     * Send a message to the client
     */
    fun send(data: String)
    
    /**
     * Close the connection
     */
    fun close()
    
    /**
     * Check if the connection is active
     */
    val isActive: Boolean
}

/**
 * Abstract base class for connections with common functionality
 */
abstract class BaseNativeRPCConnection(
    override val id: String = UUID.randomUUID().toString()
) : NativeRPCConnection {
    
    override var onMessage: ((String) -> Unit)? = null
    
    @Volatile
    protected var _isActive: Boolean = true
    override val isActive: Boolean get() = _isActive
    
    override fun close() {
        _isActive = false
        onMessage = null
    }
    
    /**
     * Helper to receive message and invoke callback.
     * Subclasses should call this when receiving data from the client.
     */
    protected fun handleReceivedData(data: String) {
        if (!_isActive) return
        onMessage?.invoke(data)
    }
}

/**
 * A simple connection implementation using callbacks.
 * Useful for testing or custom integration scenarios.
 */
class CallbackConnection(
    id: String = UUID.randomUUID().toString(),
    private val sendHandler: (String) -> Unit
) : NativeRPCConnection {
    
    override val id: String = id
    override var onMessage: ((String) -> Unit)? = null
    
    @Volatile
    private var _isActive: Boolean = true
    override val isActive: Boolean get() = _isActive
    
    override fun send(data: String) {
        if (!_isActive) return
        sendHandler(data)
    }
    
    override fun close() {
        _isActive = false
        onMessage = null
    }
    
    /**
     * Call this to simulate receiving a message from the client
     */
    fun receive(data: String) {
        if (!_isActive) return
        onMessage?.invoke(data)
    }
}
