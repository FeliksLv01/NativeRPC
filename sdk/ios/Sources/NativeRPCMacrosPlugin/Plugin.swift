//
//  Plugin.swift
//  NativeRPCMacrosPlugin
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NativeRPCMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NativeRPCServiceMacro.self
    ]
}
