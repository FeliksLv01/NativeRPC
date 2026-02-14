// NativeRPCLog.swift
// NativeRPCKit
//
// Created by 吕良(吕游)
//
// Unified logging for NativeRPCKit and related modules.

import Foundation

// MARK: - NativeRPCLog

/// Unified logging entry point for NativeRPCKit and related modules.
///
/// This is a static utility type (not a singleton instance). All modules
/// call `NativeRPCLog.debug(...)`, `NativeRPCLog.info(...)`, etc.
///
/// ## Configuration
///
/// Set the handler once at app startup to receive log messages:
///
/// ```swift
/// NativeRPCLog.handler = { level, message in
///     switch level {
///     case .debug: MyLogger.debug(message)
///     case .info: MyLogger.info(message)
///     case .warning: MyLogger.warning(message)
///     case .error: MyLogger.error(message)
///     }
/// }
/// ```
///
/// If no handler is set, no output is produced (silent by default).
///
/// ## Usage
///
/// ```swift
/// NativeRPCLog.debug("Processing request: \(request.id)")
/// NativeRPCLog.info("Connection established")
/// NativeRPCLog.warning("Deprecated API called")
/// NativeRPCLog.error("Failed to parse message: \(error)")
/// ```
public enum NativeRPCLog {
    
    // MARK: - Log Level
    
    /// Log level for NativeRPC logging.
    public enum Level: Int, Sendable, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Configuration
    
    /// Global log handler.
    ///
    /// Set this to receive log messages. If nil, no output is produced.
    nonisolated(unsafe) public static var handler: ((_ level: Level, _ message: String) -> Void)?
    
    /// Minimum log level. Messages below this level are ignored.
    /// Default is `.debug` (all messages).
    nonisolated(unsafe) public static var minimumLevel: Level = .debug
    
    // MARK: - Logging Methods
    
    /// Log a message at the specified level.
    ///
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The log message (autoclosure for lazy evaluation)
    @inlinable
    public static func log(_ level: Level, _ message: @autoclosure () -> String) {
        guard level >= minimumLevel else { return }
        handler?(level, message())
    }
    
    /// Log a debug message.
    ///
    /// Use for detailed diagnostic information during development.
    @inlinable
    public static func debug(_ message: @autoclosure () -> String) {
        log(.debug, message())
    }
    
    /// Log an info message.
    ///
    /// Use for general operational information.
    @inlinable
    public static func info(_ message: @autoclosure () -> String) {
        log(.info, message())
    }
    
    /// Log a warning message.
    ///
    /// Use for potentially problematic situations.
    @inlinable
    public static func warning(_ message: @autoclosure () -> String) {
        log(.warning, message())
    }
    
    /// Log an error message.
    ///
    /// Use for error conditions that should be addressed.
    @inlinable
    public static func error(_ message: @autoclosure () -> String) {
        log(.error, message())
    }
}
