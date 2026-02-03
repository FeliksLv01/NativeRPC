// ServiceDefinitionBuilderTest.kt
// NativeRPC Android SDK Tests
//
// Unit tests for the Params-based ServiceDefinitionBuilder DSL

package com.itoken.team.nativerpc.dsl

import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

/**
 * Test data classes for Params pattern
 */
data class AddParams(
    val value: Int
)

data class AddTwoParams(
    val a: Double,
    val b: Double
)

data class SetValueParams(
    val value: Int,
    val notify: Boolean = true
)

data class PersonParams(
    val name: String,
    val age: Int,
    val email: String? = null
)

data class PersonResult(
    val id: String,
    val name: String,
    val age: Int
)

/**
 * Tests for ServiceDefinitionBuilder DSL with Params pattern
 */
class ServiceDefinitionBuilderTest {
    
    // MARK: - Basic Function Tests
    
    @Test
    fun `Function with no params should work`() = runBlocking {
        var counter = 0
        
        val definition = serviceDefinition {
            Function<Int>("getValue") { 
                counter 
            }
            
            Function<Int>("increment") {
                counter++
                counter
            }
        }
        
        // Test getValue
        assertEquals(0, definition.call("getValue", emptyList()))
        
        // Test increment
        assertEquals(1, definition.call("increment", emptyList()))
        assertEquals(2, definition.call("increment", emptyList()))
        assertEquals(2, definition.call("getValue", emptyList()))
    }
    
    @Test
    fun `Function with Params should decode correctly`() = runBlocking {
        var counter = 0
        
        val definition = serviceDefinition {
            Function<AddParams, Int>("add") { params ->
                counter += params.value
                counter
            }
        }
        
        // Params are passed as a Map (simulating JSON-RPC)
        val params = mapOf("value" to 5)
        val result = definition.call("add", listOf(params))
        
        assertEquals(5, result)
        assertEquals(5, counter)
        
        // Add more
        val result2 = definition.call("add", listOf(mapOf("value" to 3)))
        assertEquals(8, result2)
    }
    
    @Test
    fun `Function with multiple Params fields should decode correctly`() = runBlocking {
        val definition = serviceDefinition {
            Function<AddTwoParams, Double>("addTwo") { params ->
                params.a + params.b
            }
        }
        
        val params = mapOf("a" to 10.5, "b" to 20.5)
        val result = definition.call("addTwo", listOf(params))
        
        assertEquals(31.0, result)
    }
    
    @Test
    fun `Function with optional Params field should work`() = runBlocking {
        var notified = false
        var counter = 0
        
        val definition = serviceDefinition {
            Function<SetValueParams, Int>("setValue") { params ->
                counter = params.value
                notified = params.notify
                counter
            }
        }
        
        // With notify = true
        val result1 = definition.call("setValue", listOf(mapOf("value" to 42, "notify" to true)))
        assertEquals(42, result1)
        assertTrue(notified)
        
        // With notify = false
        val result2 = definition.call("setValue", listOf(mapOf("value" to 100, "notify" to false)))
        assertEquals(100, result2)
        assertFalse(notified)
    }
    
    @Test
    fun `Function with nullable Params field should work`() = runBlocking {
        val definition = serviceDefinition {
            Function<PersonParams, String>("greet") { params ->
                val emailPart = params.email?.let { " ($it)" } ?: ""
                "Hello, ${params.name}$emailPart!"
            }
        }
        
        // Without email
        val result1 = definition.call("greet", listOf(mapOf("name" to "Alice", "age" to 30)))
        assertEquals("Hello, Alice!", result1)
        
        // With email
        val result2 = definition.call("greet", listOf(mapOf("name" to "Bob", "age" to 25, "email" to "bob@example.com")))
        assertEquals("Hello, Bob (bob@example.com)!", result2)
    }
    
    // MARK: - Complex Return Types
    
    @Test
    fun `Function returning complex type should encode to Map`() = runBlocking {
        val definition = serviceDefinition {
            Function<PersonParams, PersonResult>("createPerson") { params ->
                PersonResult(
                    id = "person-${params.name.lowercase()}",
                    name = params.name,
                    age = params.age
                )
            }
        }
        
        val result = definition.call("createPerson", listOf(mapOf("name" to "Alice", "age" to 30)))
        
        // Complex result should be encoded to Map
        assertTrue(result is Map<*, *>)
        val resultMap = result as Map<*, *>
        assertEquals("person-alice", resultMap["id"])
        assertEquals("Alice", resultMap["name"])
        assertEquals(30.0, resultMap["age"])  // Gson converts Int to Double
    }
    
    // MARK: - AsyncFunction Tests
    
    @Test
    fun `AsyncFunction with no params should work`() = runBlocking {
        var counter = 0
        
        val definition = serviceDefinition {
            AsyncFunction<Int>("fetchValue") {
                // Simulate async work
                kotlinx.coroutines.delay(10)
                counter++
                counter
            }
        }
        
        val result = definition.call("fetchValue", emptyList())
        assertEquals(1, result)
        assertEquals(1, counter)
    }
    
    @Test
    fun `AsyncFunction with Params should decode correctly`() = runBlocking {
        val definition = serviceDefinition {
            AsyncFunction<AddParams, Int>("addAsync") { params ->
                kotlinx.coroutines.delay(10)
                params.value * 2
            }
        }
        
        val result = definition.call("addAsync", listOf(mapOf("value" to 21)))
        assertEquals(42, result)
    }
    
    @Test
    fun `AsyncFunction with multiple Params should decode correctly`() = runBlocking {
        val definition = serviceDefinition {
            AsyncFunction<AddTwoParams, Double>("addTwoAsync") { params ->
                kotlinx.coroutines.delay(10)
                params.a + params.b
            }
        }
        
        val result = definition.call("addTwoAsync", listOf(mapOf("a" to 100.0, "b" to 200.0)))
        assertEquals(300.0, result)
    }
    
    // MARK: - Mixed Functions Tests
    
    @Test
    fun `Definition with mixed function types should work`() = runBlocking {
        var counter = 0
        
        val definition = serviceDefinition {
            // No-param sync
            Function<Int>("getValue") { counter }
            
            // No-param async
            AsyncFunction<Int>("fetchValue") {
                kotlinx.coroutines.delay(10)
                counter
            }
            
            // Params sync
            Function<AddParams, Int>("add") { params ->
                counter += params.value
                counter
            }
            
            // Params async
            AsyncFunction<AddParams, Int>("addAsync") { params ->
                kotlinx.coroutines.delay(10)
                counter += params.value
                counter
            }
        }
        
        // Test all functions
        assertEquals(0, definition.call("getValue", emptyList()))
        assertEquals(0, definition.call("fetchValue", emptyList()))
        
        assertEquals(5, definition.call("add", listOf(mapOf("value" to 5))))
        assertEquals(5, definition.call("getValue", emptyList()))
        
        assertEquals(15, definition.call("addAsync", listOf(mapOf("value" to 10))))
        assertEquals(15, definition.call("fetchValue", emptyList()))
    }
    
    // MARK: - Events Tests
    
    @Test
    fun `Events should be registered`() {
        val definition = serviceDefinition {
            Events("countChanged", "reset")
        }
        
        assertTrue(definition.hasEvent("countChanged"))
        assertTrue(definition.hasEvent("reset"))
        assertFalse(definition.hasEvent("nonExistent"))
        
        val eventNames = definition.getEventNames()
        assertEquals(2, eventNames.size)
        assertTrue(eventNames.contains("countChanged"))
        assertTrue(eventNames.contains("reset"))
    }
    
    // MARK: - Constants Tests
    
    @Test
    fun `Constants should be registered and retrievable`() {
        val definition = serviceDefinition {
            Constant("version") { "1.0.0" }
            Constant("maxValue") { 1000 }
            Constant("pi") { 3.14159 }
        }
        
        assertEquals("1.0.0", definition.getConstant("version"))
        assertEquals(1000, definition.getConstant("maxValue"))
        assertEquals(3.14159, definition.getConstant("pi"))
        
        val allConstants = definition.getConstants()
        assertEquals(3, allConstants.size)
    }
    
    // MARK: - Lifecycle Tests
    
    @Test
    fun `Lifecycle callbacks should be triggered`() {
        var created = false
        var destroyed = false
        
        val definition = serviceDefinition {
            OnCreate { created = true }
            OnDestroy { destroyed = true }
        }
        
        assertFalse(created)
        assertFalse(destroyed)
        
        definition.triggerLifecycle(LifecycleType.CREATE)
        assertTrue(created)
        assertFalse(destroyed)
        
        definition.triggerLifecycle(LifecycleType.DESTROY)
        assertTrue(destroyed)
    }
    
    // MARK: - Method Detection Tests
    
    @Test
    fun `canHandle should detect registered methods`() {
        val definition = serviceDefinition {
            Function<Int>("getValue") { 0 }
            AsyncFunction<Int>("fetchValue") { 0 }
        }
        
        assertTrue(definition.canHandle("getValue"))
        assertTrue(definition.canHandle("fetchValue"))
        assertFalse(definition.canHandle("nonExistent"))
    }
    
    @Test
    fun `isAsync should identify async methods`() {
        val definition = serviceDefinition {
            Function<Int>("syncMethod") { 0 }
            AsyncFunction<Int>("asyncMethod") { 0 }
        }
        
        assertFalse(definition.isAsync("syncMethod"))
        assertTrue(definition.isAsync("asyncMethod"))
    }
    
    @Test
    fun `getMethodNames should return all method names`() {
        val definition = serviceDefinition {
            Function<Int>("getValue") { 0 }
            Function<AddParams, Int>("add") { params -> params.value }
            AsyncFunction<Int>("fetchValue") { 0 }
            AsyncFunction<AddParams, Int>("addAsync") { params -> params.value }
        }
        
        val methodNames = definition.getMethodNames()
        assertEquals(4, methodNames.size)
        assertTrue(methodNames.contains("getValue"))
        assertTrue(methodNames.contains("add"))
        assertTrue(methodNames.contains("fetchValue"))
        assertTrue(methodNames.contains("addAsync"))
    }
    
    // MARK: - Primitive Return Type Tests
    
    @Test
    fun `Primitive return types should pass through directly`() = runBlocking {
        val definition = serviceDefinition {
            Function<Int>("getInt") { 42 }
            Function<Double>("getDouble") { 3.14 }
            Function<String>("getString") { "hello" }
            Function<Boolean>("getBoolean") { true }
        }
        
        assertEquals(42, definition.call("getInt", emptyList()))
        assertEquals(3.14, definition.call("getDouble", emptyList()))
        assertEquals("hello", definition.call("getString", emptyList()))
        assertEquals(true, definition.call("getBoolean", emptyList()))
    }
}
