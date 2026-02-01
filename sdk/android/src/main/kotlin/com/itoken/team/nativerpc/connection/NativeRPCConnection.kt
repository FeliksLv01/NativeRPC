// NativeRPCConnection.kt
// NativeRPC v2
//
// Connection base class that creates its own context and stub.
// Each connection manages its own per-connection service instances.

package com.itoken.team.nativerpc.connection

import android.app.Activity
import android.view.View
import com.itoken.team.nativerpc.core.NativeRPCConnectionType
import com.itoken.team.nativerpc.core.NativeRPCContext
import com.itoken.team.nativerpc.core.NativeRPCStub
import com.itoken.team.nativerpc.core.NativeRPCStubDelegate
import java.util.UUID

/**
 * Base class for NativeRPC connections.
 *
 * Each connection creates its own context and stub. The stub manages
 * per-connection service instances that are lazily created when first called.
 *
 * Subclasses must override `send()` to implement the transport layer.
 *
 * Usage:
 * ```kotlin
 * // 1. Register services at app startup
 * NativeRPCServiceCenter.register(CounterService.Factory)
 *
 * // 2. Create connection (auto-starts)
 * val connection = FlutterMethodChannelConnection(channel)
 *
 * // 3. When receiving data from client:
 * connection.handleReceivedData(jsonString)
 *
 * // 4. When done:
 * connection.close()  // destroys all service instances for this connection
 * ```
 */
abstract class NativeRPCConnection(
    /** The type of this connection */
    val connectionType: NativeRPCConnectionType,
    /** Optional root view for UI operations */
    rootView: View? = null,
    /** Optional activity for UI operations */
    activity: Activity? = null,
    /** Custom connection type name (when connectionType == CUSTOM) */
    customTypeName: String? = null
) : NativeRPCStubDelegate {
    
    // MARK: - Properties
    
    /** Unique identifier for this connection (internal use only) */
    private val id: String = UUID.randomUUID().toString()
    
    /** The context for this connection (created automatically) */
    val context: NativeRPCContext = NativeRPCContext(
        connectionType = connectionType,
        customConnectionTypeName = customTypeName,
        rootView = rootView,
        activity = activity
    )
    
    /** The stub that manages services for this connection (created automatically) */
    val stub: NativeRPCStub = NativeRPCStub(context)
    
    /** Whether this connection is currently active */
    @Volatile
    var isActive: Boolean = true
        protected set
    
    // MARK: - Initialization
    
    init {
        // Wire up the stub to use this connection for sending
        stub.delegate = this
        println("[NativeRPC] Connection created: $id (${connectionType.value})")
    }
    
    // MARK: - Abstract Methods (Subclass must implement)
    
    /**
     * Send data to the client.
     *
     * Subclasses must implement this to send the JSON string over the transport.
     *
     * @param data The JSON string to send
     */
    abstract fun send(data: String)
    
    // MARK: - NativeRPCStubDelegate
    
    /**
     * Called by the stub when it needs to send a message.
     * This forwards to the abstract send() method.
     */
    override fun sendMessage(data: String) {
        if (!isActive) return
        send(data)
    }
    
    // MARK: - Public API
    
    /**
     * Handle data received from the client.
     *
     * Call this from your transport layer when receiving JSON data.
     *
     * @param data The raw JSON string received
     */
    fun handleReceivedData(data: String) {
        if (!isActive) return
        stub.handleIncomingMessage(data)
    }
    
    /**
     * Close the connection and clean up all resources.
     *
     * This destroys all service instances for this connection.
     */
    open fun close() {
        if (!isActive) return
        
        isActive = false
        stub.shutdown()
        
        println("[NativeRPC] Connection closed: $id")
    }
    
    // MARK: - Lifecycle
    
    /**
     * Call when the app enters foreground
     */
    fun onAppForeground() {
        stub.onAppForeground()
    }
    
    /**
     * Call when the app enters background
     */
    fun onAppBackground() {
        stub.onAppBackground()
    }
}

/**
 * A simple connection implementation using callbacks.
 * Useful for testing or custom integration scenarios.
 */
class CallbackConnection(
    connectionType: NativeRPCConnectionType = NativeRPCConnectionType.CUSTOM,
    private val sendHandler: (String) -> Unit
) : NativeRPCConnection(connectionType) {
    
    override fun send(data: String) {
        if (!isActive) return
        sendHandler(data)
    }
    
    /**
     * Call this to simulate receiving a message from the client
     */
    fun receive(data: String) {
        handleReceivedData(data)
    }
}

/**
 * Creates a pair of connected connections for testing purposes.
 * Messages sent on one side are received on the other.
 */
class InMemoryConnectionPair {
    
    val client: CallbackConnection
    val server: CallbackConnection
    
    init {
        var clientRef: CallbackConnection? = null
        var serverRef: CallbackConnection? = null
        
        client = CallbackConnection { data ->
            serverRef?.receive(data)
        }
        
        server = CallbackConnection { data ->
            clientRef?.receive(data)
        }
        
        clientRef = client
        serverRef = server
    }
}
