// FlutterMethodChannelConnection.kt
// NativeRPC v2
//
// Connection implementation for Flutter using MethodChannel

package com.itoken.team.nativerpc.connection

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Connection implementation that bridges NativeRPC with Flutter's MethodChannel.
 *
 * Usage in your FlutterPlugin:
 * ```kotlin
 * val channel = MethodChannel(messenger, "com.example.nativerpc")
 * val connection = FlutterMethodChannelConnection(channel)
 * host.addConnection(connection)
 * ```
 */
class FlutterMethodChannelConnection(
    private val channel: MethodChannel,
    override val id: String = UUID.randomUUID().toString()
) : NativeRPCConnection, MethodChannel.MethodCallHandler {
    
    override var onMessage: ((String) -> Unit)? = null
    
    @Volatile
    private var _isActive: Boolean = true
    override val isActive: Boolean get() = _isActive
    
    /** Pending result callbacks by request ID */
    private val pendingResults = ConcurrentHashMap<String, MethodChannel.Result>()
    
    init {
        channel.setMethodCallHandler(this)
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!_isActive) {
            result.error("INACTIVE", "Connection is not active", null)
            return
        }
        
        when (call.method) {
            "rpc" -> handleRPCCall(call.arguments, result)
            "ping" -> result.success("pong")
            else -> result.notImplemented()
        }
    }
    
    private fun handleRPCCall(arguments: Any?, result: MethodChannel.Result) {
        try {
            val data: String = when (arguments) {
                is String -> arguments
                is Map<*, *> -> JSONObject(arguments as Map<String, Any?>).toString()
                else -> {
                    result.error("INVALID_ARGS", "Expected JSON string or Map", null)
                    return
                }
            }
            
            // Parse the request to get the ID
            val json = JSONObject(data)
            val requestId = json.optString("id")
            
            if (requestId.isEmpty()) {
                result.error("INVALID_REQUEST", "Missing request ID", null)
                return
            }
            
            // Store pending result callback
            pendingResults[requestId] = result
            
            // Forward to host
            onMessage?.invoke(data)
            
        } catch (e: Exception) {
            result.error("PARSE_ERROR", e.message, null)
        }
    }
    
    override fun send(data: String) {
        if (!_isActive) return
        
        try {
            val json = JSONObject(data)
            val messageType = json.optString("type")
            
            if (messageType == "event") {
                // Events are pushed to Flutter via invokeMethod
                channel.invokeMethod("event", data)
            } else {
                // Response to a pending request
                val requestId = json.optString("id")
                pendingResults.remove(requestId)?.let { result ->
                    result.success(data)
                }
            }
        } catch (e: Exception) {
            println("[NativeRPC] Failed to parse outgoing message: ${e.message}")
        }
    }
    
    override fun close() {
        if (!_isActive) return
        _isActive = false
        
        // Clear all pending results
        for ((_, result) in pendingResults) {
            result.error("CLOSED", "Connection closed", null)
        }
        pendingResults.clear()
        
        // Remove method handler
        channel.setMethodCallHandler(null)
        onMessage = null
    }
}

/**
 * Connection implementation for Flutter EventChannel (one-way streaming from native to Flutter).
 * Use this when you only need to send events to Flutter without RPC calls.
 */
class FlutterEventChannelConnection(
    private val eventChannel: EventChannel,
    override val id: String = UUID.randomUUID().toString()
) : NativeRPCConnection, EventChannel.StreamHandler {
    
    override var onMessage: ((String) -> Unit)? = null
    
    @Volatile
    private var _isActive: Boolean = true
    override val isActive: Boolean get() = _isActive
    
    private var eventSink: EventChannel.EventSink? = null
    
    init {
        eventChannel.setStreamHandler(this)
    }
    
    // MARK: - EventChannel.StreamHandler
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
    
    // MARK: - NativeRPCConnection
    
    override fun send(data: String) {
        if (!_isActive) return
        eventSink?.success(data)
    }
    
    override fun close() {
        if (!_isActive) return
        _isActive = false
        
        eventSink?.endOfStream()
        eventSink = null
        eventChannel.setStreamHandler(null)
        onMessage = null
    }
}
