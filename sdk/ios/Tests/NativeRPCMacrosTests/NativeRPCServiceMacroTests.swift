//
//  NativeRPCServiceMacroTests.swift
//  NativeRPCMacrosTests
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(NativeRPCMacrosPlugin)
import NativeRPCMacrosPlugin
#endif

final class NativeRPCServiceMacroTests: XCTestCase {
    
    let testMacros: [String: Macro.Type] = [
        "NativeRPCService": NativeRPCServiceMacro.self,
    ]
    
    // MARK: - Success Cases
    
    func testMacroExpansion() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("counter")
            final class CounterService: NativeRPCService {
            }
            """,
            expandedSource: """
            final class CounterService: NativeRPCService {

                override class var serviceName: String {
                    "counter"
                }

                @_silgen_name("_nrpc_service_getter_CounterService")
                private static func _nrpc_service_getter() -> UnsafeRawPointer {
                    unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
                }

                @_section("__DATA_CONST,__nrpc_service")
                @_used
                private static let _nrpc_service_item = _nrpc_service_getter
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroExpansionWithDifferentName() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("user")
            final class UserRPCService: NativeRPCService {
            }
            """,
            expandedSource: """
            final class UserRPCService: NativeRPCService {

                override class var serviceName: String {
                    "user"
                }

                @_silgen_name("_nrpc_service_getter_UserRPCService")
                private static func _nrpc_service_getter() -> UnsafeRawPointer {
                    unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
                }

                @_section("__DATA_CONST,__nrpc_service")
                @_used
                private static let _nrpc_service_item = _nrpc_service_getter
            }
            """,
            macros: testMacros
        )
    }
    
    func testMacroExpansionWithModuleQualifiedType() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("settings")
            final class SettingsService: NativeRPCKit.NativeRPCService {
            }
            """,
            expandedSource: """
            final class SettingsService: NativeRPCKit.NativeRPCService {

                override class var serviceName: String {
                    "settings"
                }

                @_silgen_name("_nrpc_service_getter_SettingsService")
                private static func _nrpc_service_getter() -> UnsafeRawPointer {
                    unsafeBitCast(Self.self, to: UnsafeRawPointer.self)
                }

                @_section("__DATA_CONST,__nrpc_service")
                @_used
                private static let _nrpc_service_item = _nrpc_service_getter
            }
            """,
            macros: testMacros
        )
    }
    
    // MARK: - Error Cases
    
    func testErrorNotAClass() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("test")
            struct MyStruct {}
            """,
            expandedSource: """
            struct MyStruct {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@NativeRPCService can only be applied to a class.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testErrorMissingInheritance() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("test")
            class MyService {
            }
            """,
            expandedSource: """
            class MyService {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@NativeRPCService requires the class to have an inheritance clause.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testErrorMissingNativeRPCServiceConformance() throws {
        assertMacroExpansion(
            """
            @NativeRPCService("test")
            class MyService: NSObject {
            }
            """,
            expandedSource: """
            class MyService: NSObject {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@NativeRPCService requires the class to inherit from NativeRPCService.", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}
