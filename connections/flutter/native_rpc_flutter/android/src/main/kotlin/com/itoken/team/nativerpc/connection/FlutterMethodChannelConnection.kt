// FlutterMethodChannelConnection.kt
// NativeRPC v2
//
// Connection implementation for Flutter using MethodChannel
//
// NOTE: This file is in the Flutter plugin, not the SDK, because it depends on Flutter classes.
//
// Usage (new architecture):
// ```kotlin
// // 1. Register services at app startup
// NativeRPCServiceCenter.register(MyService.Factory)
//
// // 2. Create connection
// val channel = MethodChannel(messenger, "native_rpc")
// val connection = FlutterMethodChannelConnection(channel)
//
// // 3. Connection auto-starts and is ready to use
//
// // 4. When done
// connection.close()
// ```

package com.itoken.team.nativerpc.connection

import android.app.Activity
import com.itoken.team.nativerpc.core.NativeRPCConnectionType
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

/**
 * Connection implementation that bridges NativeRPC with Flutter's MethodChannel.
 *
 * This connection extends `NativeRPCConnection` base class and handles:
 * - Receiving RPC requests from Flutter via MethodChannel
 * - Forwarding requests to the stub for processing
 * - Sending responses back to Flutter
 * - Pushing events/notifications to Flutter via invokeMethod
 *
 * ## Protocol
 *
 * Uses simplified JSON-RPC 2.0:
 * - Request:      `{"id": "1", "method": "service.method", "params": {...}}`
 * - Response:     `{"id": "1", "result": ...}`
 * - Error:        `{"id": "1", "error": {"code": -32601, "message": "..."}}`
 * - Notification: `{"method": "service.event", "params": {...}}` (no id)
 *
 * ## Usage
 *
 * ```kotlin
 * // Register services first
 * NativeRPCServiceCenter.register(CounterService.Factory)
 *
 * // Create connection with channel
 * val channel = MethodChannel(messenger, "native_rpc")
 * val connection = FlutterMethodChannelConnection(channel)
 *
 * // Connection auto-starts and is ready to handle calls
 * ```
 */
class FlutterMethodChannelConnection(
    private val channel: MethodChannel,
    activity: Activity? = null
) : NativeRPCConnection(
    connectionType = NativeRPCConnectionType.FLUTTER,
    activity = activity
), MethodChannel.MethodCallHandler {
    
    // MARK: - Properties
    
    /** Pending result callbacks by request ID */
    private val pendingResults = ConcurrentHashMap<String, MethodChannel.Result>()
    
    // MARK: - Initialization
    
    init {
        // Set up method handler
        channel.setMethodCallHandler(this)
    }
    
    // MARK: - MethodChannel.MethodCallHandler
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!isActive) {
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
            
            // Parse the request to get the ID (JSON-RPC format)
            val json = JSONObject(data)
            val requestId = json.optString("id")
            
            if (requestId.isEmpty()) {
                result.error("INVALID_REQUEST", "Missing request ID", null)
                return
            }
            
            // Store pending result callback
            pendingResults[requestId] = result
            
            // Forward to stub for processing
            handleReceivedData(data)
            
        } catch (e: Exception) {
            result.error("PARSE_ERROR", e.message, null)
        }
    }
    
    // MARK: - Send (Override)
    
    /**
     * Send data to Flutter.
     *
     * - For responses (with id): completes the pending MethodChannel.Result
     * - For notifications (without id): invokes "notification" method on Flutter
     */
    override fun send(data: String) {
        if (!isActive) return
        
        try {
            val json = JSONObject(data)
            
            // Check if this is a notification (no id) or a response (has id)
            if (json.has("id")) {
                // Response to a pending request - complete the Flutter result
                val requestId = json.optString("id")
                pendingResults.remove(requestId)?.let { result ->
                    result.success(data)
                }
            } else {
                // Notification (event) - push to Flutter via invokeMethod
                channel.invokeMethod("notification", data)
            }
        } catch (e: Exception) {
            println("[NativeRPC Flutter] Failed to parse outgoing message: ${e.message}")
        }
    }
    
    // MARK: - Close (Override)
    
    /**
     * Close the connection and clean up resources.
     */
    override fun close() {
        if (!isActive) return
        
        // Clear all pending results with error
        for ((_, result) in pendingResults) {
            result.error("CLOSED", "Connection closed", null)
        }
        pendingResults.clear()
        
        // Remove method handler
        channel.setMethodCallHandler(null)
        
        // Call super to clean up stub and context
        super.close()
    }
}

/**
 * Connection implementation for Flutter EventChannel (one-way streaming from native to Flutter).
 *
 * Use this when you only need to send events to Flutter without RPC calls.
 *
 * ## Usage
 *
 * ```kotlin
 * // Register services
 * NativeRPCServiceCenter.register(SensorService.Factory)
 *
 * // Create event channel connection
 * val eventChannel = EventChannel(messenger, "native_rpc_events")
 * val connection = FlutterEventChannelConnection(eventChannel)
 *
 * // Events will be pushed to Flutter when services emit them
 * ```
 */
class FlutterEventChannelConnection(
    private val eventChannel: EventChannel,
    activity: Activity? = null
) : NativeRPCConnection(
    connectionType = NativeRPCConnectionType.FLUTTER,
    activity = activity
), EventChannel.StreamHandler {
    
    // MARK: - Properties
    
    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    
    // MARK: - Initialization
    
    init {
        // Set up stream handler
        eventChannel.setStreamHandler(this)
    }
    
    // MARK: - EventChannel.StreamHandler
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
    
    // MARK: - Send (Override)
    
    /**
     * Send data to Flutter via EventChannel.
     */
    override fun send(data: String) {
        if (!isActive) return
        eventSink?.success(data)
    }
    
    // MARK: - Close (Override)
    
    /**
     * Close the connection and clean up resources.
     */
    override fun close() {
        if (!isActive) return
        
        eventSink?.endOfStream()
        eventSink = null
        eventChannel.setStreamHandler(null)
        
        // Call super to clean up stub and context
        super.close()
    }
}
