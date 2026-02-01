// NativeRpcPlugin.kt
// NativeRPC v2
//
// Flutter plugin entry point for Android

package com.itoken.team.nativerpc

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.itoken.team.nativerpc.core.NativeRPCHost
import com.itoken.team.nativerpc.core.NativeRPCService

/**
 * NativeRPC Flutter Plugin for Android
 *
 * This plugin provides the bridge between Flutter and NativeRPC.
 * It registers itself with Flutter and routes RPC calls to the NativeRPCHost.
 *
 * Usage in your Application or Activity:
 * ```kotlin
 * // Register services before Flutter initializes, or in your Application class
 * NativeRpcPlugin.registerService(CounterService())
 * NativeRpcPlugin.registerService(UserService())
 * ```
 */
class NativeRpcPlugin : FlutterPlugin, MethodCallHandler {
    
    companion object {
        /**
         * The shared NativeRPC host instance
         */
        @Volatile
        private var _sharedHost: NativeRPCHost? = null
        
        /**
         * Get or create the shared host
         */
        val sharedHost: NativeRPCHost
            get() {
                if (_sharedHost == null) {
                    synchronized(this) {
                        if (_sharedHost == null) {
                            _sharedHost = NativeRPCHost()
                        }
                    }
                }
                return _sharedHost!!
            }
        
        /**
         * Register a service with the shared host.
         * Call this before Flutter initializes, typically in your Application class.
         */
        fun registerService(service: NativeRPCService) {
            sharedHost.register(service)
        }
        
        /**
         * Register multiple services at once
         */
        fun registerServices(vararg services: NativeRPCService) {
            for (service in services) {
                sharedHost.register(service)
            }
        }
    }
    
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_rpc")
        channel.setMethodCallHandler(this)
        
        // Start the host if not already started
        println("[NativeRPC] Plugin attached to Flutter engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "rpc" -> {
                val message = call.arguments as? String
                if (message == null) {
                    result.error("INVALID_ARGUMENT", "Expected string argument", null)
                    return
                }
                
                // Process through the host
                sharedHost.handleMessage(message) { response ->
                    if (response != null) {
                        result.success(response)
                    } else {
                        result.error("NO_RESPONSE", "No response from host", null)
                    }
                }
            }
            
            "ping" -> {
                result.success("pong")
            }
            
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        println("[NativeRPC] Plugin detached from Flutter engine")
    }
}
