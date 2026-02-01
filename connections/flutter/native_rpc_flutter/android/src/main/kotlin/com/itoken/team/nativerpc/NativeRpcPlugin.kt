// NativeRpcPlugin.kt
// NativeRPC v2
//
// Flutter plugin entry point for Android
// Uses NativeRPCServiceCenter + FlutterMethodChannelConnection architecture

package com.itoken.team.nativerpc

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import com.itoken.team.nativerpc.connection.FlutterMethodChannelConnection
import com.itoken.team.nativerpc.core.NativeRPCServiceCenter
import com.itoken.team.nativerpc.core.NativeRPCServiceFactory
import com.itoken.team.nativerpc.core.NativeRPCService

/**
 * NativeRPC Flutter Plugin for Android
 *
 * This plugin provides the bridge between Flutter and NativeRPC using the new
 * NativeRPCServiceCenter architecture.
 *
 * ## New Architecture (v2.1)
 *
 * Services are:
 * - **Registered by factory** at app startup via `NativeRPCServiceCenter`
 * - **Instantiated per-connection** when first called
 * - **Destroyed** when the connection closes
 *
 * ## Usage
 *
 * In your Application class or MainActivity:
 * ```kotlin
 * // 1. Register service factories at app startup
 * NativeRPCServiceCenter.register(CounterService.Factory)
 * // or using lambda:
 * NativeRPCServiceCenter.register("counter") { context ->
 *     CounterService(context)
 * }
 *
 * // 2. The plugin handles connection setup automatically
 * ```
 *
 * ## Legacy Migration
 *
 * Old code:
 * ```kotlin
 * NativeRpcPlugin.registerService(CounterService())  // ❌ Deprecated
 * ```
 *
 * New code:
 * ```kotlin
 * NativeRPCServiceCenter.register(CounterService.Factory)  // ✅ New
 * ```
 */
class NativeRpcPlugin : FlutterPlugin, ActivityAware {
    
    companion object {
        private const val CHANNEL_NAME = "native_rpc"
        
        /**
         * Register a service factory with the global service center.
         * Call this before Flutter initializes, typically in your Application class.
         *
         * @param factory The service factory to register
         *
         * Example:
         * ```kotlin
         * NativeRpcPlugin.register(CounterService.Factory)
         * ```
         */
        fun <T : NativeRPCService> register(factory: NativeRPCServiceFactory<T>) {
            NativeRPCServiceCenter.register(factory)
        }
        
        /**
         * Register a service with a lambda factory.
         *
         * @param serviceName The unique name for this service
         * @param factory Lambda that creates service instances
         *
         * Example:
         * ```kotlin
         * NativeRpcPlugin.register("counter") { context ->
         *     CounterService(context)
         * }
         * ```
         */
        fun <T : NativeRPCService> register(
            serviceName: String,
            factory: (com.itoken.team.nativerpc.core.NativeRPCContext?) -> T
        ) {
            NativeRPCServiceCenter.register(serviceName, factory = factory)
        }
        
        /**
         * Register multiple service factories at once
         */
        fun register(vararg factories: NativeRPCServiceFactory<*>) {
            NativeRPCServiceCenter.register(*factories)
        }
        
        // MARK: - Deprecated API (for migration)
        
        /**
         * @deprecated Use NativeRPCServiceCenter.register(factory) instead.
         * This method exists only for backward compatibility during migration.
         */
        @Deprecated(
            message = "Use NativeRPCServiceCenter.register(factory) instead",
            replaceWith = ReplaceWith("NativeRPCServiceCenter.register(factory)")
        )
        fun registerService(service: NativeRPCService) {
            println("[NativeRPC] Warning: registerService(instance) is deprecated. Use NativeRPCServiceCenter.register(factory) instead.")
            // Legacy support: wrap the instance in a factory that always returns the same instance
            // This is not ideal (no per-connection isolation) but maintains backward compatibility
            val serviceName = service.name
            NativeRPCServiceCenter.register(serviceName) { _ -> service }
        }
        
        /**
         * @deprecated Use NativeRPCServiceCenter.register(factory) instead.
         */
        @Deprecated(
            message = "Use NativeRPCServiceCenter.register(...factories) instead",
            replaceWith = ReplaceWith("NativeRPCServiceCenter.register(*factories)")
        )
        fun registerServices(vararg services: NativeRPCService) {
            for (service in services) {
                @Suppress("DEPRECATION")
                registerService(service)
            }
        }
    }
    
    // MARK: - Instance Properties
    
    private var channel: MethodChannel? = null
    private var connection: FlutterMethodChannelConnection? = null
    private var activity: Activity? = null

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        this.channel = methodChannel
        
        // Create connection (uses NativeRPCServiceCenter internally)
        val conn = FlutterMethodChannelConnection(
            channel = methodChannel,
            activity = activity
        )
        this.connection = conn
        
        println("[NativeRPC] Plugin attached to Flutter engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Close connection and clean up
        connection?.close()
        connection = null
        channel = null
        
        println("[NativeRPC] Plugin detached from Flutter engine")
    }
    
    // MARK: - ActivityAware
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // Store activity in context storage for services to access
        connection?.context?.set("activity", activity)
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        connection?.context?.remove<Activity>("activity")
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        connection?.context?.set("activity", activity)
    }
    
    override fun onDetachedFromActivity() {
        connection?.context?.remove<Activity>("activity")
        activity = null
    }
}
