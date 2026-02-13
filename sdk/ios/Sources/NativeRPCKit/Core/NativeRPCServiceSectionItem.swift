//
//  NativeRPCServiceSectionItem.swift
//  NativeRPCKit
//

import Foundation

/// Function pointer type that returns the service metatype as an UnsafeRawPointer.
/// This is used for compile-time constant storage in Mach-O sections.
public typealias NativeRPCServiceMetatypeGetter = @convention(c) () -> UnsafeRawPointer

/// A C-layout compatible structure to be written into the `__DATA_CONST,__nrpc_service` section.
/// This structure is used by the `@NativeRPCService` macro to register services at compile time.
///
/// The structure contains a function pointer that returns the service metatype (class object).
///
/// - Important: This structure must maintain strict C-layout compatibility for Mach-O section storage.
public struct NativeRPCServiceSectionItem {
    /// Function pointer that returns the service metatype as UnsafeRawPointer.
    /// At runtime, this is called and the result is cast back to the service type.
    public let getter: NativeRPCServiceMetatypeGetter
    
    /// Creates a new section item.
    /// - Parameter getter: Function pointer returning the service metatype
    public init(getter: @escaping NativeRPCServiceMetatypeGetter) {
        self.getter = getter
    }
}
