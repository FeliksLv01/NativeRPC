import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RPCServiceRegisterMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw RPCServiceRegisterMacroError.notAClass
        }

        guard classDecl.inheritanceClause != nil else {
            throw RPCServiceRegisterMacroError.missingInheritance
        }

        let hasConformance = classDecl.inheritanceClause?.inheritedTypes.contains { type in
            if let identifierType = type.type.as(IdentifierTypeSyntax.self) {
                let name = identifierType.name.text
                return name == "NativeRPCService" || name == "NativeRPCServiceRegistrable"
            }
            if let memberType = type.type.as(MemberTypeSyntax.self) {
                let name = memberType.name.text
                return name == "NativeRPCService" || name == "NativeRPCServiceRegistrable"
            }
            return false
        } ?? false

        if !hasConformance {
            throw RPCServiceRegisterMacroError.missingNativeRPCServiceConformance
        }

        guard case .argumentList(let arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let serviceName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            throw RPCServiceRegisterMacroError.missingServiceName
        }

        let className = classDecl.name.text

        return [
            """
            override class var serviceName: String {
                "\(raw: serviceName)"
            }
            """,
            """
            private static let _nrpc_service_getter: @convention(c) () -> UnsafeRawPointer = {
                unsafeBitCast(\(raw: className).self, to: UnsafeRawPointer.self)
            }
            """,
            """
            @_section("__DATA_CONST,__nrpc_service")
            @_used
            private static let _nrpc_service_item = _nrpc_service_getter
            """
        ]
    }
}

// MARK: - Errors

enum RPCServiceRegisterMacroError: Error, CustomStringConvertible {
    case notAClass
    case missingInheritance
    case missingNativeRPCServiceConformance
    case missingServiceName

    var description: String {
        switch self {
        case .notAClass:
            return "@RPCServiceRegister can only be applied to a class."
        case .missingInheritance:
            return "@RPCServiceRegister requires the class to have an inheritance clause."
        case .missingNativeRPCServiceConformance:
            return "@RPCServiceRegister requires the class to inherit from NativeRPCService or conform to NativeRPCServiceRegistrable."
        case .missingServiceName:
            return "@RPCServiceRegister requires a service name argument, e.g. @RPCServiceRegister(\"counter\")."
        }
    }
}
