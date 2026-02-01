package com.example.flutter_counter

import com.itoken.team.nativerpc.core.NativeRPCService
import com.itoken.team.nativerpc.dsl.serviceDefinition

class CounterService : NativeRPCService() {
    private var count = 0
    
    override fun definition() = serviceDefinition {
        Name("counter")
        
        Function0<Int>("getValue") {
            count
        }
        
        Function0<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Function0<Int>("decrement") {
            count--
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Function0<Int>("reset") {
            count = 0
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}
