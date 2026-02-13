//
//  NativeRPCServiceMacro.swift
//  NativeRPCMacrosPlugin
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Macro implementation for `@NativeRPCService`.
///
/// This macro generates:
/// 1. `override class var serviceName: String` with the provided name
/// 2. A static getter function that returns the metatype as UnsafeRawPointer
/// 3. A static section item stored in `__DATA_CONST,__nrpc_service`
///
/// Example expansion:
/// ```swift
/// @NativeRPCService("counter")
/// final class CounterService: NativeRPCService { ... }
/// ```
/// Expands to:
/// ```swift
/// final class CounterService: NativeRPCService {
///     ...
///     override class var serviceName: String { "counter" }
///
///     @_silgen_name("_nrpc_service_getter_CounterService")
///     private static func _nrpc_service_getter() -> UnsafeRawPointer {
///         unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
///     }
///
///     @_section("__DATA_CONST,__nrpc_service")
///     @_used
///     private static let _nrpc_service_item: NativeRPCServiceSectionItem = .init(
///         getter: _nrpc_service_getter
///     )
/// }
/// ```
public struct NativeRPCServiceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Validate that the macro is attached to a class
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw NativeRPCServiceMacroError.notAClass
        }
        
        // 2. Validate inheritance clause exists (must have a superclass or protocol)
        guard classDecl.inheritanceClause != nil else {
            throw NativeRPCServiceMacroError.missingInheritance
        }
        
        // 3. Check for NativeRPCService or NativeRPCServiceRegistrable conformance
        let hasNativeRPCServiceConformance = classDecl.inheritanceClause?.inheritedTypes.contains { type in
            // Handle simple type identifier
            if let identifierType = type.type.as(IdentifierTypeSyntax.self) {
                let name = identifierType.name.text
                return name == "NativeRPCService" || name == "NativeRPCServiceRegistrable"
            }
            // Handle member type identifier (e.g. Module.NativeRPCService)
            if let memberType = type.type.as(MemberTypeSyntax.self) {
                let name = memberType.name.text
                return name == "NativeRPCService" || name == "NativeRPCServiceRegistrable"
            }
            return false
        } ?? false
        
        if !hasNativeRPCServiceConformance {
            throw NativeRPCServiceMacroError.missingNativeRPCServiceConformance
        }
        
        // 4. Extract the service name from macro arguments
        guard case .argumentList(let arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let serviceName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            throw NativeRPCServiceMacroError.missingServiceName
        }
        
        let className = classDecl.name.text
        
        // 5. Generate serviceName, getter function and section item
        return [
            """
            override class var serviceName: String {
                "\(raw: serviceName)"
            }
            """,
            """
            @_silgen_name("_nrpc_service_getter_\(raw: className)")
            private static func _nrpc_service_getter() -> UnsafeRawPointer {
                unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
            }
            """,
            """
            @_section("__DATA_CONST,__nrpc_service")
            @_used
            private static let _nrpc_service_item: NativeRPCServiceSectionItem = .init(
                getter: _nrpc_service_getter
            )
            """
        ]
    }
}

// MARK: - Errors

enum NativeRPCServiceMacroError: Error, CustomStringConvertible {
    case notAClass
    case missingInheritance
    case missingNativeRPCServiceConformance
    case missingServiceName
    
    var description: String {
        switch self {
        case .notAClass:
            return "@NativeRPCService can only be applied to a class."
        case .missingInheritance:
            return "@NativeRPCService requires the class to have an inheritance clause."
        case .missingNativeRPCServiceConformance:
            return "@NativeRPCService requires the class to inherit from NativeRPCService or conform to NativeRPCServiceRegistrable."
        case .missingServiceName:
            return "@NativeRPCService requires a service name argument, e.g. @NativeRPCService(\"counter\")."
        }
    }
}
