// CounterService.swift
// NativeRPC Example
//
// A simple counter service demonstrating NativeRPC DSL usage

import Foundation
import native_rpc

/// Example CounterService that demonstrates the NativeRPC DSL
class CounterService: NativeRPCService, @unchecked Sendable {
    
    /// The current counter value
    private var count: Int = 0
    
    /// Build the service definition using the DSL
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("counter")
        
        // Constants - use explicit closure syntax
        Constant("initialValue", 0)
        Constant("maxValue", 1000)
        
        // Get the current counter value
        Function("getValue") { [weak self] () -> Int in
            self?.count ?? 0
        }
        
        // Increment the counter and return the new value
        Function("increment") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count += 1
            // Emit event when count changes
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        // Decrement the counter and return the new value
        Function("decrement") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count -= 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        // Add a value to the counter
        Function("add") { [weak self] (value: Int) -> Int in
            guard let self = self else { return 0 }
            self.count += value
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        // Reset the counter to zero
        Function("reset") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count = 0
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        // Set the counter to a specific value
        Function("setValue") { [weak self] (value: Int) -> Int in
            guard let self = self else { return 0 }
            self.count = value
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        // MARK: - Async Function Examples
        
        // Async function using Swift async/await
        // Simulates a network delay before returning the counter value
        AsyncFunction("getValueDelayed") { [weak self] (delayMs: Int) async throws -> Int in
            // Simulate network delay
            try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            return self?.count ?? 0
        }
        
        // Async function that runs on the main thread
        // Useful for UI-related operations
        AsyncFunction("getValueOnMain") { [weak self] () async throws -> Int in
            // This runs on main thread - safe for UI operations
            return self?.count ?? 0
        }.runOnMain()
        
        // Async function with multiple parameters
        // Simulates a delayed add operation
        AsyncFunction("addDelayed") { [weak self] (value: Int, delayMs: Int) async throws -> Int in
            guard let self = self else { return 0 }
            
            // Simulate processing delay
            try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            
            // Update counter
            self.count += value
            self.emit("countChanged", data: ["count": self.count])
            
            return self.count
        }
        
        // Async function that can fail
        // Demonstrates error handling
        AsyncFunction("divideBy") { [weak self] (divisor: Int) async throws -> Int in
            guard let self = self else { return 0 }
            
            if divisor == 0 {
                throw NativeRPCError.invalidParams("Cannot divide by zero")
            }
            
            // Simulate some async work
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            return self.count / divisor
        }
        
        // Async function using Promise (for callback-based APIs)
        // Demonstrates bridging legacy callback APIs
        AsyncFunction("fetchRemoteValue") { [weak self] (promise: Promise) in
            // Simulate a callback-based API (e.g., legacy network call)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                // Simulate success response
                let remoteValue = (self?.count ?? 0) * 2
                promise.resolve(["remoteValue": remoteValue, "timestamp": Date().timeIntervalSince1970])
            }
        }.withTimeout(5.0) // 5 second timeout
        
        // Promise-based async with parameters
        AsyncFunction("multiplyAsync") { (multiplier: Int, promise: Promise) in
            // Simulate async multiplication
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else {
                    promise.reject(message: "Service not available")
                    return
                }
                let result = self.count * multiplier
                promise.resolve(result)
            }
        }
        
        // Declare events this service can emit
        Events("countChanged")
        
        // Lifecycle hooks
        OnCreate {
            print("[CounterService] Service created")
        }
        
        OnDestroy {
            print("[CounterService] Service destroyed")
        }
    }
}
