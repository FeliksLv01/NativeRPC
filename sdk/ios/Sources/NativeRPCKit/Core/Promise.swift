// Promise.swift
// NativeRPC v2
//
// Promise type for callback-style async functions (similar to Expo Modules)
//
// Usage:
// ```swift
// AsyncFunction("fetchData") { (id: String, promise: Promise) in
//     someAsyncOperation(id) { result, error in
//         if let error = error {
//             promise.reject(error)
//         } else {
//             promise.resolve(result)
//         }
//     }
// }
// ```

import Foundation

/// Promise type for callback-style async functions
///
/// Use this when you need to bridge callback-based APIs to the RPC system.
/// For native Swift async/await, use `AsyncFunction` with `async throws` closure instead.
///
/// Example:
/// ```swift
/// // Callback-style (legacy APIs)
/// AsyncFunction("legacyFetch") { (url: String, promise: Promise) in
///     LegacyAPI.fetch(url) { result, error in
///         if let error = error {
///             promise.reject(error)
///         } else {
///             promise.resolve(result)
///         }
///     }
/// }
///
/// // Modern Swift async/await (preferred)
/// AsyncFunction("modernFetch") { (url: String) async throws -> Data in
///     try await URLSession.shared.data(from: URL(string: url)!).0
/// }
/// ```
public final class Promise: @unchecked Sendable {
    
    /// Callback when promise resolves successfully
    public typealias Resolver = @Sendable (Any?) -> Void
    
    /// Callback when promise rejects with error
    public typealias Rejecter = @Sendable (Error) -> Void
    
    private let resolver: Resolver
    private let rejecter: Rejecter
    private var isSettled = false
    private let lock = NSLock()
    
    /// Initialize a promise with resolve and reject callbacks
    public init(resolver: @escaping Resolver, rejecter: @escaping Rejecter) {
        self.resolver = resolver
        self.rejecter = rejecter
    }
    
    // MARK: - Resolve
    
    /// Resolve the promise with a value
    public func resolve(_ value: Any? = nil) {
        settle {
            resolver(value)
        }
    }
    
    /// Resolve the promise with no value (void)
    public func resolve() {
        resolve(nil)
    }
    
    // MARK: - Reject
    
    /// Reject the promise with an error
    public func reject(_ error: Error) {
        settle {
            rejecter(error)
        }
    }
    
    /// Reject the promise with a NativeRPCError
    public func reject(_ error: NativeRPCError) {
        settle {
            rejecter(error)
        }
    }
    
    /// Reject the promise with code and message
    public func reject(code: Int, message: String, data: Any? = nil) {
        reject(NativeRPCError(code: code, message: message, data: data))
    }
    
    /// Reject the promise with a message (uses internal error code)
    public func reject(message: String) {
        reject(NativeRPCError.internalError(message))
    }
    
    // MARK: - Private
    
    private func settle(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isSettled else {
            print("[NativeRPC] Warning: Promise already settled, ignoring duplicate resolve/reject")
            return
        }
        
        isSettled = true
        action()
    }
}

// MARK: - Promise Detection

/// Protocol to detect if a type is Promise (for function signature detection)
public protocol AnyPromise {}

extension Promise: AnyPromise {}
