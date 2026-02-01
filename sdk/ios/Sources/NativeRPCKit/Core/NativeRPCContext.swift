// NativeRPCContext.swift
// NativeRPC v2
//
// Connection-scoped context that holds configuration and shared state.
// Services can access connection info and store custom data here.

import Foundation

#if os(iOS)
import UIKit
/// Platform-specific type alias for the native view class (UIView on iOS)
public typealias NativeView = UIView
/// Platform-specific type alias for the native view controller class (UIViewController on iOS)
public typealias NativeViewController = UIViewController
#elseif os(macOS)
import AppKit
/// Platform-specific type alias for the native view class (NSView on macOS)
public typealias NativeView = NSView
/// Platform-specific type alias for the native view controller class (NSViewController on macOS)
public typealias NativeViewController = NSViewController
#endif

// MARK: - Connection Type

/// Represents the type of connection used for RPC communication
public enum NativeRPCConnectionType: String, Sendable {
    /// Flutter MethodChannel connection
    case flutter
    /// WKWebView JavaScript bridge connection
    case webView
    /// WebSocket connection
    case webSocket
    /// React Native bridge connection
    case reactNative
    /// Custom connection type
    case custom
}

// MARK: - Read-Write Lock Wrapper

/// A lightweight read-write lock wrapper using pthread_rwlock for high-performance concurrent reads.
private final class ContextRWLock {
    private var lock = pthread_rwlock_t()
    
    init() {
        pthread_rwlock_init(&lock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&lock)
    }
    
    /// Execute a closure while holding the read lock
    func withReadLock<T>(_ body: () throws -> T) rethrows -> T {
        pthread_rwlock_rdlock(&lock)
        defer { pthread_rwlock_unlock(&lock) }
        return try body()
    }
    
    /// Execute a closure while holding the write lock
    func withWriteLock<T>(_ body: () throws -> T) rethrows -> T {
        pthread_rwlock_wrlock(&lock)
        defer { pthread_rwlock_unlock(&lock) }
        return try body()
    }
}

// MARK: - NativeRPCContext

/// A context object that holds configuration and state for a specific RPC connection.
///
/// Each connection has its own context, and all services created for that connection
/// share the same context. Services can use the context to:
/// - Access connection information (type)
/// - Store and retrieve custom data (shared across services)
/// - Access platform-specific views/controllers
///
/// Example usage in a service:
/// ```swift
/// class UserService: NativeRPCService {
///     func someMethod() {
///         // Store data for other services to access
///         context?.set("currentUserId", value: "user123")
///         
///         // Read data stored by other services
///         let theme: String? = context?.get("appTheme")
///     }
/// }
/// ```
///
/// Note: Marked `@unchecked Sendable` because mutable state (`storage`) is protected
/// by the internal read-write lock. Safety invariant: All storage access is synchronized.
public final class NativeRPCContext: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The type of connection this context belongs to
    public let connectionType: NativeRPCConnectionType
    
    /// Custom connection type name (only used when connectionType == .custom)
    public let customConnectionTypeName: String?
    
    /// The root view associated with this context (platform-specific)
    public private(set) weak var rootView: NativeView?
    
    /// The root view controller associated with this context (platform-specific)
    public private(set) weak var rootViewController: NativeViewController?
    
    /// Custom storage for services to share data
    private var storage: [String: Any] = [:]
    
    /// Read-write lock for thread-safe storage access (faster than NSLock for read-heavy workloads)
    private let rwLock = ContextRWLock()
    
    // MARK: - Initialization
    
    /// Creates a new RPC context
    ///
    /// - Parameters:
    ///   - connectionType: The type of connection
    ///   - customTypeName: Custom type name (only when connectionType == .custom)
    ///   - rootView: Optional root view for UI operations
    ///   - rootViewController: Optional root view controller for UI operations
    public init(
        connectionType: NativeRPCConnectionType,
        customTypeName: String? = nil,
        rootView: NativeView? = nil,
        rootViewController: NativeViewController? = nil
    ) {
        self.connectionType = connectionType
        self.customConnectionTypeName = customTypeName
        self.rootView = rootView
        self.rootViewController = rootViewController
    }
    
    // MARK: - Storage API
    
    /// Store a value in the context's shared storage
    ///
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The value to store
    ///
    /// Example:
    /// ```swift
    /// context.set("userId", value: "user123")
    /// context.set("preferences", value: ["theme": "dark"])
    /// ```
    public func set<T>(_ key: String, value: T) {
        rwLock.withWriteLock {
            storage[key] = value
        }
    }
    
    /// Retrieve a value from the context's shared storage
    ///
    /// - Parameter key: The key to look up
    /// - Returns: The value if it exists and can be cast to the expected type, nil otherwise
    ///
    /// Example:
    /// ```swift
    /// let userId: String? = context.get("userId")
    /// let preferences: [String: Any]? = context.get("preferences")
    /// ```
    public func get<T>(_ key: String) -> T? {
        rwLock.withReadLock {
            storage[key] as? T
        }
    }
    
    /// Remove a value from the context's shared storage
    ///
    /// - Parameter key: The key to remove
    /// - Returns: The removed value if it existed, nil otherwise
    @discardableResult
    public func remove<T>(_ key: String) -> T? {
        rwLock.withWriteLock {
            storage.removeValue(forKey: key) as? T
        }
    }
    
    /// Check if a key exists in the storage
    ///
    /// - Parameter key: The key to check
    /// - Returns: true if the key exists, false otherwise
    public func contains(_ key: String) -> Bool {
        rwLock.withReadLock {
            storage[key] != nil
        }
    }
    
    /// Clear all stored values
    public func clearStorage() {
        rwLock.withWriteLock {
            storage.removeAll()
        }
    }
    
    // MARK: - Convenience
    
    /// Get the connection type as a descriptive string
    public var connectionTypeDescription: String {
        if connectionType == .custom, let customName = customConnectionTypeName {
            return customName
        }
        return connectionType.rawValue
    }
}
