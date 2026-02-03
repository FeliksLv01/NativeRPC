// CounterService.kt
// NativeRPC Example
//
// A simple counter service demonstrating NativeRPC DSL usage with Params pattern

package com.nativerpc.native_rpc_example

import com.itoken.team.nativerpc.core.NativeRPCService
import com.itoken.team.nativerpc.core.NativeRPCContext
import com.itoken.team.nativerpc.core.NativeRPCServiceFactory
import com.itoken.team.nativerpc.dsl.serviceDefinition

// region Params Types

/**
 * Parameters for `add` method
 */
data class AddParams(
    val value: Int
)

/**
 * Parameters for `setValue` method
 */
data class SetValueParams(
    val value: Int
)

// endregion

/**
 * Example CounterService that demonstrates the NativeRPC DSL with Params pattern.
 * 
 * This service uses the new type-safe Params pattern where method parameters
 * are bundled into data classes (like iOS's Codable structs).
 */
class CounterService(context: NativeRPCContext? = null) : NativeRPCService() {
    
    // region Factory
    
    companion object {
        /**
         * Factory for creating CounterService instances per-connection.
         * Register with: NativeRPCServiceCenter.register(CounterService.Factory)
         */
        val Factory = object : NativeRPCServiceFactory<CounterService> {
            override val serviceName = "counter"
            override fun create(context: NativeRPCContext?) = CounterService(context)
        }
    }
    
    // endregion
    
    // region Initialization
    
    init {
        this.internalContext = context
    }
    
    // endregion
    
    /** The current counter value */
    private var count: Int = 0
    
    /**
     * Build the service definition using the DSL with Params pattern
     */
    override fun definition() = serviceDefinition {
        // Note: Name is auto-set from Factory.serviceName
        
        // Constants
        Constant("initialValue") { 0 }
        Constant("maxValue") { 1000 }
        
        // Get the current counter value (no params)
        Function<Int>("getValue") { 
            count 
        }
        
        // Increment the counter and return the new value (no params)
        Function<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Decrement the counter and return the new value (no params)
        Function<Int>("decrement") {
            count--
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Add a value to the counter (with Params)
        Function<AddParams, Int>("add") { params ->
            count += params.value
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Reset the counter to zero (no params)
        Function<Int>("reset") {
            count = 0
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Set the counter to a specific value (with Params)
        Function<SetValueParams, Int>("setValue") { params ->
            count = params.value
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Declare events this service can emit
        Events("countChanged")
        
        // Lifecycle hooks
        OnCreate {
            println("[CounterService] Service created")
        }
        
        OnDestroy {
            println("[CounterService] Service destroyed")
        }
    }
}
