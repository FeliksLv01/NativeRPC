//
//  NativeRPCServiceAutoRegistrar.swift
//  NativeRPCKit
//

import Foundation

/// Automatically registers all services marked with `@NativeRPCService` macro
/// to `NativeRPCServiceCenter`.
///
/// Usage:
/// ```swift
/// // Call once at app startup (e.g., in AppDelegate or @main)
/// NativeRPCServiceAutoRegistrar.registerAll()
/// ```
///
/// The registrar scans the Mach-O `__DATA_CONST,__nrpc_service` section to find
/// all services registered at compile time via the `@NativeRPCService` macro,
/// then registers them with `NativeRPCServiceCenter.shared`.
public enum NativeRPCServiceAutoRegistrar {
    
    /// Uses Swift's `static let` dispatch_once semantics for thread-safe one-time initialization.
    private static let _performRegistration: Void = {
        let serviceTypes = NativeRPCServiceScanner.scan()
        for serviceType in serviceTypes {
            if let registrableType = serviceType as? any NativeRPCServiceRegistrable.Type {
                NativeRPCServiceCenter.shared.register(registrableType)
            }
        }
    }()
    
    /// Scans and registers all services marked with `@NativeRPCService`.
    ///
    /// This method is idempotent - calling it multiple times has no effect
    /// after the first successful registration. Thread-safe via Swift's
    /// static let dispatch_once semantics.
    public static func registerAll() {
        _ = _performRegistration
    }
}
