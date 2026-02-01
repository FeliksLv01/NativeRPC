// NativeRPCServiceCenter.swift
// NativeRPC v2
//
// Global singleton that stores service types/factories.
// Services are registered here by type, then instantiated per-connection by NativeRPCStub.

import Foundation

// MARK: - Service Factory Protocol

/// Protocol for service types that can be instantiated by the service center.
/// Services must provide a `name` and an initializer that accepts a context.
public protocol NativeRPCServiceRegistrable: NativeRPCServiceProtocol {
    /// The unique name identifying this service (e.g., "counter", "user")
    static var serviceName: String { get }
    
    /// Connection types this service supports (defaults to all)
    static var supportedConnectionTypes: Set<NativeRPCConnectionType> { get }
    
    /// Create a new instance of this service with the given context
    init(context: NativeRPCContext?)
}

// MARK: - Default Implementation

extension NativeRPCServiceRegistrable {
    /// By default, services support all connection types
    public static var supportedConnectionTypes: Set<NativeRPCConnectionType> {
        return [.flutter, .webView, .webSocket, .reactNative, .custom]
    }
}

// MARK: - Service Registration Entry

/// Internal storage for a registered service type
private struct ServiceRegistration {
    let serviceType: any NativeRPCServiceRegistrable.Type
    let supportedConnectionTypes: Set<NativeRPCConnectionType>
}

// MARK: - Read-Write Lock Wrapper

/// A lightweight read-write lock wrapper using pthread_rwlock for high-performance concurrent reads.
private final class ReadWriteLock {
    private var lock = pthread_rwlock_t()
    
    init() {
        pthread_rwlock_init(&lock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&lock)
    }
    
    /// Acquire read lock (allows concurrent readers)
    func readLock() {
        pthread_rwlock_rdlock(&lock)
    }
    
    /// Acquire write lock (exclusive access)
    func writeLock() {
        pthread_rwlock_wrlock(&lock)
    }
    
    /// Release the lock (works for both read and write)
    func unlock() {
        pthread_rwlock_unlock(&lock)
    }
    
    /// Execute a closure while holding the read lock
    func withReadLock<T>(_ body: () throws -> T) rethrows -> T {
        readLock()
        defer { unlock() }
        return try body()
    }
    
    /// Execute a closure while holding the write lock
    func withWriteLock<T>(_ body: () throws -> T) rethrows -> T {
        writeLock()
        defer { unlock() }
        return try body()
    }
}

// MARK: - NativeRPCServiceCenter

/// Global singleton that stores service types/factories.
///
/// Services are registered here by type (not instance), then instantiated
/// per-connection by `NativeRPCStub` when first needed.
///
/// Usage:
/// ```swift
/// // At app startup - register service types
/// NativeRPCServiceCenter.shared.register(CounterService.self)
/// NativeRPCServiceCenter.shared.register(UserService.self)
///
/// // Services are instantiated per-connection when first called
/// // (handled automatically by NativeRPCStub)
/// ```
///
/// Note: Marked `@unchecked Sendable` because mutable state (`registrations`)
/// is protected by the internal read-write lock.
/// Safety invariant: All access to `registrations` is synchronized via `rwLock`.
public final class NativeRPCServiceCenter: @unchecked Sendable {
    
    // MARK: - Singleton
    
    /// The shared service center instance
    public static let shared = NativeRPCServiceCenter()
    
    // MARK: - Properties
    
    /// Registered service types by name
    private var registrations: [String: ServiceRegistration] = [:]
    
    /// Read-write lock for thread-safe access (faster than NSLock for read-heavy workloads)
    private let rwLock = ReadWriteLock()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a service type with the service center.
    ///
    /// The service type must conform to `NativeRPCServiceRegistrable` which requires:
    /// - A static `serviceName` property
    /// - An `init(context:)` initializer
    ///
    /// - Parameter serviceType: The service type to register
    ///
    /// Example:
    /// ```swift
    /// NativeRPCServiceCenter.shared.register(CounterService.self)
    /// ```
    public func register<T: NativeRPCServiceRegistrable>(_ serviceType: T.Type) {
        rwLock.withWriteLock {
            let name = T.serviceName
            
            if registrations[name] != nil {
                print("[NativeRPC] Warning: Service '\(name)' is already registered, replacing...")
            }
            
            registrations[name] = ServiceRegistration(
                serviceType: serviceType,
                supportedConnectionTypes: T.supportedConnectionTypes
            )
            
            print("[NativeRPC] Registered service type: \(name)")
        }
    }
    
    /// Register multiple service types at once
    ///
    /// Example:
    /// ```swift
    /// NativeRPCServiceCenter.shared.register(
    ///     CounterService.self,
    ///     UserService.self,
    ///     SettingsService.self
    /// )
    /// ```
    public func register(_ serviceTypes: any NativeRPCServiceRegistrable.Type...) {
        for serviceType in serviceTypes {
            registerAny(serviceType)
        }
    }
    
    /// Internal helper to register type-erased service types
    private func registerAny(_ serviceType: any NativeRPCServiceRegistrable.Type) {
        rwLock.withWriteLock {
            let name = serviceType.serviceName
            
            if registrations[name] != nil {
                print("[NativeRPC] Warning: Service '\(name)' is already registered, replacing...")
            }
            
            registrations[name] = ServiceRegistration(
                serviceType: serviceType,
                supportedConnectionTypes: serviceType.supportedConnectionTypes
            )
            
            print("[NativeRPC] Registered service type: \(name)")
        }
    }
    
    /// Unregister a service type by name
    ///
    /// - Parameter name: The service name to unregister
    public func unregister(name: String) {
        rwLock.withWriteLock {
            if registrations.removeValue(forKey: name) != nil {
                print("[NativeRPC] Unregistered service type: \(name)")
            }
        }
    }
    
    /// Unregister a service type
    ///
    /// - Parameter serviceType: The service type to unregister
    public func unregister<T: NativeRPCServiceRegistrable>(_ serviceType: T.Type) {
        unregister(name: T.serviceName)
    }
    
    // MARK: - Service Lookup (Internal)
    
    /// Get the service type for a given name.
    /// This is called by `NativeRPCStub` to instantiate services.
    ///
    /// - Parameter name: The service name
    /// - Returns: The service type if registered, nil otherwise
    func serviceType(named name: String) -> (any NativeRPCServiceRegistrable.Type)? {
        rwLock.withReadLock {
            registrations[name]?.serviceType
        }
    }
    
    /// Check if a service supports a given connection type
    ///
    /// - Parameters:
    ///   - name: The service name
    ///   - connectionType: The connection type to check
    /// - Returns: true if the service supports the connection type
    func supportsConnectionType(serviceName name: String, connectionType: NativeRPCConnectionType) -> Bool {
        rwLock.withReadLock {
            guard let registration = registrations[name] else {
                return false
            }
            return registration.supportedConnectionTypes.contains(connectionType)
        }
    }
    
    // MARK: - Introspection
    
    /// Get list of all registered service names
    public func getRegisteredServiceNames() -> [String] {
        rwLock.withReadLock {
            Array(registrations.keys).sorted()
        }
    }
    
    /// Check if a service is registered
    ///
    /// - Parameter name: The service name to check
    /// - Returns: true if the service is registered
    public func isRegistered(name: String) -> Bool {
        rwLock.withReadLock {
            registrations[name] != nil
        }
    }
    
    /// Check if a service type is registered
    public func isRegistered<T: NativeRPCServiceRegistrable>(_ serviceType: T.Type) -> Bool {
        return isRegistered(name: T.serviceName)
    }
    
    // MARK: - Reset (for testing)
    
    /// Remove all registered services. Primarily for testing.
    public func reset() {
        rwLock.withWriteLock {
            registrations.removeAll()
            print("[NativeRPC] Service center reset")
        }
    }
}
