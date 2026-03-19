import Foundation

@attached(member, names: named(serviceName), named(_nrpc_service_getter), named(_nrpc_service_item))
public macro RPCServiceRegister(_ name: String) = #externalMacro(module: "NativeRPCKitMacros", type: "RPCServiceRegisterMacro")
