// FlutterMethodChannelConnection.swift
// native_rpc_flutter
//
// Connection implementation for Flutter using MethodChannel
// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)

import Flutter
import UIKit
import NativeRPCKit

// MARK: - Flutter Method Channel Connection

/// Connection implementation that bridges NativeRPC with Flutter's MethodChannel.
///
/// Protocol: Simplified JSON-RPC 2.0
/// - Request:      {"id": "1", "method": "service.method", "params": {...}}
/// - Response:     {"id": "1", "result": ...}
/// - Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
/// - Notification: {"method": "service.event", "params": {...}}  (no id)
///
/// Usage in your AppDelegate:
/// ```swift
/// let channel = FlutterMethodChannel(
///     name: "native_rpc",
///     binaryMessenger: controller.binaryMessenger
/// )
///
/// let connection = FlutterMethodChannelConnection(channel: channel)
/// host.addConnection(connection)
/// ```
public final class FlutterMethodChannelConnection: NativeRPCConnection {
    
    public let id: String
    public var onMessage: ((Data) -> Void)?
    
    private let channel: FlutterMethodChannel
    
    private var _isActive: Bool = true
    public var isActive: Bool { _isActive }
    
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// Pending result callbacks by request ID
    private var pendingResults: [String: FlutterResult] = [:]
    
    public init(channel: FlutterMethodChannel, id: String = UUID().uuidString) {
        self.channel = channel
        self.id = id
        
        setupMethodHandler()
    }
    
    private func setupMethodHandler() {
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard _isActive else {
            result(FlutterError(code: "INACTIVE", message: "Connection is not active", details: nil))
            return
        }
        
        switch call.method {
        case "rpc":
            // The RPC message is passed as a JSON string
            handleRPCCall(call.arguments, result: result)
            
        case "ping":
            // Health check
            result("pong")
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleRPCCall(_ arguments: Any?, result: @escaping FlutterResult) {
        do {
            let data: Data
            
            if let jsonString = arguments as? String {
                // Message passed as JSON string
                guard let d = jsonString.data(using: .utf8) else {
                    result(FlutterError(code: "PARSE_ERROR", message: "Invalid JSON string", details: nil))
                    return
                }
                data = d
            } else if let dict = arguments as? [String: Any] {
                // Message passed as a Map
                data = try JSONSerialization.data(withJSONObject: dict)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected JSON string or Map", details: nil))
                return
            }
            
            // Parse the request to get the ID (JSON-RPC format)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let requestId = json["id"] as? String {
                
                // Store pending result callback
                pendingResults[requestId] = result
                
                // Forward to host for processing
                onMessage?(data)
            } else {
                result(FlutterError(code: "INVALID_REQUEST", message: "Missing request ID", details: nil))
            }
            
        } catch {
            result(FlutterError(code: "PARSE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    public func send(_ data: Data) {
        guard _isActive else { return }
        
        do {
            // Parse the response to check if it's a notification or response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // Check if this is a notification (no id) or a response (has id)
            if let requestId = json["id"] as? String {
                // Response to a pending request - complete the Flutter result
                if let result = pendingResults.removeValue(forKey: requestId) {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        result(jsonString)
                    }
                }
            } else {
                // Notification (event) - push to Flutter via invokeMethod
                // Format: {"method": "service.event", "params": {...}}
                if let jsonString = String(data: data, encoding: .utf8) {
                    channel.invokeMethod("notification", arguments: jsonString)
                }
            }
            
        } catch {
            print("[NativeRPC] Failed to parse outgoing message: \(error)")
        }
    }
    
    public func close() {
        guard _isActive else { return }
        _isActive = false
        
        // Clear all pending results with error
        for (_, result) in pendingResults {
            result(FlutterError(code: "CLOSED", message: "Connection closed", details: nil))
        }
        pendingResults.removeAll()
        
        // Remove method handler
        channel.setMethodCallHandler(nil)
        onMessage = nil
    }
}

// MARK: - Event Channel Connection (for streaming events)

/// Connection implementation for Flutter EventChannel (one-way streaming from native to Flutter).
/// Use this when you only need to send events to Flutter without RPC calls.
public final class FlutterEventChannelConnection: NSObject, NativeRPCConnection, FlutterStreamHandler {
    
    public let id: String
    public var onMessage: ((Data) -> Void)?
    
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    
    private var _isActive: Bool = true
    public var isActive: Bool { _isActive }
    
    public init(eventChannel: FlutterEventChannel, id: String = UUID().uuidString) {
        self.eventChannel = eventChannel
        self.id = id
        super.init()
        
        eventChannel.setStreamHandler(self)
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - NativeRPCConnection
    
    public func send(_ data: Data) {
        guard _isActive, let eventSink = eventSink else { return }
        
        if let jsonString = String(data: data, encoding: .utf8) {
            eventSink(jsonString)
        }
    }
    
    public func close() {
        guard _isActive else { return }
        _isActive = false
        
        eventSink?(FlutterEndOfEventStream)
        eventSink = nil
        eventChannel.setStreamHandler(nil)
        onMessage = nil
    }
}
