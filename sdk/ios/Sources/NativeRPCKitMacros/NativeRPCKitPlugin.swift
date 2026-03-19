import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
public struct NativeRPCKitPlugin: CompilerPlugin {
    public init() {}
    public let providingMacros: [Macro.Type] = [
        RPCServiceRegisterMacro.self,
    ]
}
