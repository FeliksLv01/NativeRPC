// FlutterMethodChannelConnection.swift
// native_rpc_flutter
//
// Connection implementation for Flutter using MethodChannel
// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)
//
// Usage (new architecture):
// ```swift
// // 1. Register services at app startup
// NativeRPCServiceCenter.shared.register(MyService.self)
//
// // 2. Create connection
// let channel = FlutterMethodChannel(name: "native_rpc", binaryMessenger: messenger)
// let connection = FlutterMethodChannelConnection(channel: channel)
//
// // 3. Connection auto-starts and is ready to use
//
// // 4. When done
// connection.close()
// ```

import Flutter
import UIKit
import NativeRPCKit

// MARK: - Flutter Method Channel Connection

/// Connection implementation that bridges NativeRPC with Flutter's MethodChannel.
///
/// This connection extends `NativeRPCConnection` base class and handles:
/// - Receiving RPC requests from Flutter via MethodChannel
/// - Forwarding requests to the stub for processing
/// - Sending responses back to Flutter
/// - Pushing events/notifications to Flutter via invokeMethod
///
/// ## Protocol
///
/// Uses simplified JSON-RPC 2.0:
/// - Request:      `{"id": "1", "method": "service.method", "params": {...}}`
/// - Response:     `{"id": "1", "result": ...}`
/// - Error:        `{"id": "1", "error": {"code": -32601, "message": "..."}}`
/// - Notification: `{"method": "service.event", "params": {...}}` (no id)
///
/// ## Usage
///
/// ```swift
/// // Register services first
/// NativeRPCServiceCenter.shared.register(CounterService.self)
///
/// // Create connection with channel
/// let channel = FlutterMethodChannel(name: "native_rpc", binaryMessenger: messenger)
/// let connection = FlutterMethodChannelConnection(channel: channel)
///
/// // Connection auto-starts and is ready to handle calls
/// ```
public final class FlutterMethodChannelConnection: NativeRPCConnection, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The Flutter method channel
    private let channel: FlutterMethodChannel
    
    /// Pending result callbacks by request ID
    private var pendingResults: [String: FlutterResult] = [:]
    private let pendingLock = NSLock()
    
    // MARK: - Initialization
    
    /// Create a new Flutter MethodChannel connection.
    ///
    /// The connection automatically sets up the method handler and is ready to use.
    ///
    /// - Parameters:
    ///   - channel: The Flutter MethodChannel to use
    ///   - rootViewController: Optional root view controller for UI operations
    public init(
        channel: FlutterMethodChannel,
        rootViewController: NativeViewController? = nil
    ) {
        self.channel = channel
        
        super.init(
            connectionType: .flutter,
            rootView: nil,
            rootViewController: rootViewController
        )
        
        // Set up method handler
        setupMethodHandler()
    }
    
    // MARK: - Setup
    
    private func setupMethodHandler() {
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
    }
    
    // MARK: - Method Call Handling
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isActive else {
            result(FlutterError(code: "INACTIVE", message: "Connection is not active", details: nil))
            return
        }
        
        switch call.method {
        case "rpc":
            handleRPCCall(call.arguments, result: result)
            
        case "ping":
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
                pendingLock.lock()
                pendingResults[requestId] = result
                pendingLock.unlock()
                
                // Forward to stub for processing
                handleReceivedData(data)
            } else {
                result(FlutterError(code: "INVALID_REQUEST", message: "Missing request ID", details: nil))
            }
            
        } catch {
            result(FlutterError(code: "PARSE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Send (Override)
    
    /// Send a JSON string to Flutter.
    ///
    /// - For responses (with id): completes the pending FlutterResult
    /// - For notifications (without id): invokes "notification" method on Flutter
    public override func send(_ jsonString: String) {
        guard isActive else { return }
        
        do {
            guard let data = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // Check if this is a notification (no id) or a response (has id)
            if let requestId = json["id"] as? String {
                // Response to a pending request - complete the Flutter result
                pendingLock.lock()
                let pendingResult = pendingResults.removeValue(forKey: requestId)
                pendingLock.unlock()
                
                if let result = pendingResult {
                    DispatchQueue.main.async {
                        result(jsonString)
                    }
                }
            } else {
                // Notification (event) - push to Flutter via invokeMethod
                DispatchQueue.main.async { [weak self] in
                    self?.channel.invokeMethod("notification", arguments: jsonString)
                }
            }
            
        } catch {
            print("[NativeRPC Flutter] Failed to parse outgoing message: \(error)")
        }
    }
    
    // MARK: - Close (Override)
    
    /// Close the connection and clean up resources.
    public override func close() {
        guard isActive else { return }
        
        // Clear all pending results with error
        pendingLock.lock()
        let results = pendingResults
        pendingResults.removeAll()
        pendingLock.unlock()
        
        for (_, result) in results {
            DispatchQueue.main.async {
                result(FlutterError(code: "CLOSED", message: "Connection closed", details: nil))
            }
        }
        
        // Remove method handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.channel.setMethodCallHandler(nil)
        }
        
        // Call super to clean up stub and context
        super.close()
    }
}

// MARK: - Event Channel Connection (for streaming events)

/// Connection implementation for Flutter EventChannel (one-way streaming from native to Flutter).
///
/// Use this when you only need to send events to Flutter without RPC calls.
///
/// ## Usage
///
/// ```swift
/// // Register services
/// NativeRPCServiceCenter.shared.register(SensorService.self)
///
/// // Create event channel connection
/// let eventChannel = FlutterEventChannel(name: "native_rpc_events", binaryMessenger: messenger)
/// let connection = FlutterEventChannelConnection(eventChannel: eventChannel)
///
/// // Events will be pushed to Flutter when services emit them
/// ```
public final class FlutterEventChannelConnection: NativeRPCConnection, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private let sinkLock = NSLock()
    private var streamHandler: StreamHandlerDelegate?
    
    // MARK: - Initialization
    
    /// Create a new Flutter EventChannel connection.
    ///
    /// - Parameters:
    ///   - eventChannel: The Flutter EventChannel to use
    ///   - rootViewController: Optional root view controller for UI operations
    public init(
        eventChannel: FlutterEventChannel,
        rootViewController: NativeViewController? = nil
    ) {
        self.eventChannel = eventChannel
        
        super.init(
            connectionType: .flutter,
            rootView: nil,
            rootViewController: rootViewController
        )
        
        // Set up stream handler using NSObject wrapper
        let handler = StreamHandlerDelegate { [weak self] events in
            self?.sinkLock.lock()
            self?.eventSink = events
            self?.sinkLock.unlock()
            return nil
        } onCancel: { [weak self] in
            self?.sinkLock.lock()
            self?.eventSink = nil
            self?.sinkLock.unlock()
            return nil
        }
        self.streamHandler = handler
        eventChannel.setStreamHandler(handler)
    }
    
    // MARK: - Send (Override)
    
    /// Send a JSON string to Flutter via EventChannel.
    public override func send(_ jsonString: String) {
        guard isActive else { return }
        
        sinkLock.lock()
        let sink = eventSink
        sinkLock.unlock()
        
        guard let eventSink = sink else {
            return
        }
        
        DispatchQueue.main.async {
            eventSink(jsonString)
        }
    }
    
    // MARK: - Close (Override)
    
    /// Close the connection and clean up resources.
    public override func close() {
        guard isActive else { return }
        
        sinkLock.lock()
        let sink = eventSink
        eventSink = nil
        sinkLock.unlock()
        
        // Send end of stream on main thread
        DispatchQueue.main.async { [weak self] in
            sink?(FlutterEndOfEventStream)
            self?.eventChannel.setStreamHandler(nil)
            self?.streamHandler = nil
        }
        
        // Call super to clean up stub and context
        super.close()
    }
}

// MARK: - StreamHandlerDelegate (NSObject wrapper for FlutterStreamHandler)

/// Internal NSObject wrapper that conforms to FlutterStreamHandler.
/// This is needed because NativeRPCConnection doesn't inherit from NSObject,
/// but FlutterStreamHandler requires NSObjectProtocol conformance.
private final class StreamHandlerDelegate: NSObject, FlutterStreamHandler {
    
    private let onListenHandler: (@escaping FlutterEventSink) -> FlutterError?
    private let onCancelHandler: () -> FlutterError?
    
    init(
        onListen: @escaping (@escaping FlutterEventSink) -> FlutterError?,
        onCancel: @escaping () -> FlutterError?
    ) {
        self.onListenHandler = onListen
        self.onCancelHandler = onCancel
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        return onListenHandler(events)
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return onCancelHandler()
    }
}
