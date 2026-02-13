//
//  NativeRPCServiceMacro.swift
//  NativeRPCMacros
//

import NativeRPCKit

/// Marks a class for automatic registration with `NativeRPCServiceCenter`.
///
/// Use this macro to decorate an `NativeRPCService` subclass. It generates:
/// - `override class var serviceName: String` with the provided name
/// - A static symbol in the `__DATA_CONST,__nrpc_service` Mach-O section for auto-registration
///
/// Example:
/// ```swift
/// @NativeRPCService("counter")
/// final class CounterService: NativeRPCService {
///     required init(context: NativeRPCContext?) {
///         super.init(context: context)
///     }
///
///     @ServiceDefinitionBuilder
///     override func definition() -> ServiceDefinitionContainer {
///         Function("increment") { () -> Int in
///             // ...
///         }
///     }
/// }
/// ```
///
/// At app startup, call `NativeRPCServiceAutoRegistrar.registerAll()` to register
/// all services marked with this macro.
///
/// - Parameter name: The service name used for RPC routing (e.g., "counter" for "counter.increment")
/// - Note: The class must inherit from `NativeRPCService`.
@attached(member, names: named(serviceName), named(_nrpc_service_getter), named(_nrpc_service_item))
public macro NativeRPCService(_ name: String) = #externalMacro(module: "NativeRPCMacrosPlugin", type: "NativeRPCServiceMacro")
