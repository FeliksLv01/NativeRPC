// CounterService.kt
// NativeRPC Example
//
// A simple counter service demonstrating NativeRPC DSL usage

package com.nativerpc.native_rpc_example

import com.itoken.team.nativerpc.core.NativeRPCService
import com.itoken.team.nativerpc.dsl.serviceDefinition

/**
 * Example CounterService that demonstrates the NativeRPC DSL
 */
class CounterService : NativeRPCService() {
    
    /** The current counter value */
    private var count: Int = 0
    
    /**
     * Build the service definition using the DSL
     */
    override fun definition() = serviceDefinition {
        Name("counter")
        
        // Constants
        Constant("initialValue") { 0 }
        Constant("maxValue") { 1000 }
        
        // Get the current counter value
        Function0<Int>("getValue") { 
            count 
        }
        
        // Increment the counter and return the new value
        Function0<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Decrement the counter and return the new value
        Function0<Int>("decrement") {
            count--
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Add a value to the counter
        Function1<Int, Int>("add") { value ->
            count += value
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Reset the counter to zero
        Function0<Int>("reset") {
            count = 0
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        // Set the counter to a specific value
        Function1<Int, Int>("setValue") { value ->
            count = value
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
