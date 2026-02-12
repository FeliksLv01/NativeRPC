// NativeRPCConnection.swift
// NativeRPC v2
//
// Connection base class - subclass and override send() to implement custom transports

import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - NativeRPCConnection

/// Base class for RPC connections.
///
/// To implement a custom connection, simply subclass and override `send(_ jsonString:)`:
///
/// ```swift
/// class MyWebSocketConnection: NativeRPCConnection {
///     let socket: WebSocket
///
///     init(socket: WebSocket) {
///         self.socket = socket
///         super.init(connectionType: .webSocket)
///
///         socket.onMessage = { [weak self] data in
///             self?.handleReceivedData(data)
///         }
///     }
///
///     override func send(_ jsonString: String) {
///         socket.send(jsonString)
///     }
/// }
/// ```
///
/// That's it! The base class handles:
/// - Creating context and stub
/// - Routing messages to services
/// - Managing service lifecycle
/// - Cleaning up on close
///
/// Note: Marked `@unchecked Sendable` because mutable state is protected
/// by controlled access patterns (set once, unidirectional state transitions).
open class NativeRPCConnection: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Internal identifier for this connection (used for logging)
    private let id: String = UUID().uuidString
    
    /// The type of connection
    public let connectionType: NativeRPCConnectionType
    
    /// Whether the connection is active
    public private(set) var isActive: Bool = true
    
    /// The context for this connection (available after init)
    public private(set) var context: NativeRPCContext?
    
    /// The stub that manages services (internal)
    private(set) var stub: NativeRPCStub?
    
    // MARK: - Initialization
    
    /// Create a new connection.
    ///
    /// The connection is automatically started and ready to use.
    ///
    /// - Parameters:
    ///   - connectionType: The type of connection (flutter, webView, etc.)
    ///   - rootView: Optional root view for UI operations
    ///   - rootViewController: Optional root view controller for UI operations
    public init(
        connectionType: NativeRPCConnectionType,
        rootView: NativeView? = nil,
        rootViewController: NativeViewController? = nil
    ) {
        self.connectionType = connectionType
        
        // Auto-start: create context and stub
        let ctx = NativeRPCContext(
            connectionType: connectionType,
            customTypeName: nil,
            rootView: rootView,
            rootViewController: rootViewController
        )
        self.context = ctx
        
        let newStub = NativeRPCStub(context: ctx)
        newStub.delegate = self
        self.stub = newStub
    }
    
    /// Create a connection with custom type name.
    ///
    /// Use this when connectionType is `.custom`.
    public convenience init(
        customTypeName: String,
        rootView: NativeView? = nil,
        rootViewController: NativeViewController? = nil
    ) {
        self.init(
            connectionType: .custom,
            rootView: rootView,
            rootViewController: rootViewController
        )
        // Update context with custom type name
        if self.context != nil {
            // Context is immutable, so we need to recreate it
            let newCtx = NativeRPCContext(
                connectionType: .custom,
                customTypeName: customTypeName,
                rootView: rootView,
                rootViewController: rootViewController
            )
            self.context = newCtx
            self.stub = NativeRPCStub(context: newCtx)
            self.stub?.delegate = self
        }
    }
    
    // MARK: - Send (Override in Subclass)
    
    /// Send a JSON string to the client.
    ///
    /// **Subclasses must override this method.**
    ///
    /// - Parameter jsonString: The JSON string to send
    open func send(_ jsonString: String) {
        fatalError("Subclass must override send(_:)")
    }
    
    // MARK: - Receive (Call from Subclass)
    
    /// Call this when data is received from the client.
    ///
    /// This routes the message to the appropriate service.
    ///
    /// - Parameter data: The received JSON data
    public func handleReceivedData(_ data: Data) {
        guard isActive else { return }
        stub?.handleIncomingMessage(data)
    }
    
    /// Call this when a string message is received from the client.
    ///
    /// Convenience method that converts string to data.
    ///
    /// - Parameter string: The received JSON string
    public func handleReceivedString(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        handleReceivedData(data)
    }
    
    // MARK: - Lifecycle
    
    /// Close the connection and clean up all resources.
    ///
    /// This destroys all service instances created for this connection.
    open func close() {
        guard isActive else { return }
        
        isActive = false
        
        // Shutdown stub (destroys all services)
        stub?.shutdown()
        stub = nil
        
        // Clear context
        context = nil
    }
    
    // MARK: - App Lifecycle
    
    /// Notify all services that app entered foreground
    public func onAppForeground() {
        stub?.onAppForeground()
    }
    
    /// Notify all services that app entered background
    public func onAppBackground() {
        stub?.onAppBackground()
    }
    
    // MARK: - Introspection
    
    /// Get list of instantiated service names for this connection
    public func getActiveServiceNames() -> [String] {
        return stub?.getActiveServiceNames() ?? []
    }
    
    /// Get list of active event subscriptions for this connection
    public func getActiveSubscriptions() -> [String] {
        return stub?.getActiveSubscriptions() ?? []
    }
}

// MARK: - NativeRPCStubDelegate

extension NativeRPCConnection: NativeRPCStubDelegate {
    public func sendMessage(_ jsonString: String) {
        guard isActive else { return }
        send(jsonString)
    }
}

// MARK: - CallbackConnection (for testing)

/// A simple connection that uses a callback for sending.
///
/// Useful for testing or simple integrations:
///
/// ```swift
/// let connection = CallbackConnection(connectionType: .custom) { jsonString in
///     myTransport.send(jsonString)
/// }
///
/// // When receiving data:
/// connection.receive(incomingData)
/// ```
public final class CallbackConnection: NativeRPCConnection, @unchecked Sendable {
    
    private let sendHandler: (String) -> Void
    
    public init(
        connectionType: NativeRPCConnectionType,
        sendHandler: @escaping (String) -> Void
    ) {
        self.sendHandler = sendHandler
        super.init(connectionType: connectionType)
    }
    
    public override func send(_ jsonString: String) {
        guard isActive else { return }
        sendHandler(jsonString)
    }
    
    /// Simulate receiving data from the client
    public func receive(_ data: Data) {
        handleReceivedData(data)
    }
    
    /// Simulate receiving a string message from the client
    public func receive(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        receive(data)
    }
}

// MARK: - InMemoryConnectionPair (for testing)

/// Creates a pair of connected connections for testing.
///
/// Messages sent on one side are received on the other:
///
/// ```swift
/// let pair = InMemoryConnectionPair()
///
/// // Send from client, receive on server
/// pair.client.send(jsonString)  // server receives it
///
/// // Send from server, receive on client
/// pair.server.send(jsonString)  // client receives it
/// ```
public final class InMemoryConnectionPair {
    
    public let client: CallbackConnection
    public let server: CallbackConnection
    
    public init(
        clientType: NativeRPCConnectionType = .custom,
        serverType: NativeRPCConnectionType = .custom
    ) {
        var clientRef: CallbackConnection?
        var serverRef: CallbackConnection?
        
        client = CallbackConnection(connectionType: clientType) { jsonString in
            serverRef?.receive(jsonString)
        }
        
        server = CallbackConnection(connectionType: serverType) { jsonString in
            clientRef?.receive(jsonString)
        }
        
        clientRef = client
        serverRef = server
    }
    
    /// Close both connections
    public func close() {
        client.close()
        server.close()
    }
}
