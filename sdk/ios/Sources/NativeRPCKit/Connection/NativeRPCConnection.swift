// NativeRPCConnection.swift
// NativeRPC v2
//
// Connection protocol and base implementations

import Foundation

// MARK: - Connection Protocol

/// Protocol for connections between native and clients (Flutter, WebView, etc.)
///
/// Note: Implementations should be thread-safe as they may be accessed from multiple queues.
public protocol NativeRPCConnection: AnyObject, Sendable {
    
    /// Unique identifier for this connection
    var id: String { get }
    
    /// Callback invoked when a message is received from the client
    var onMessage: ((Data) -> Void)? { get set }
    
    /// Send a message to the client
    func send(_ data: Data)
    
    /// Close the connection
    func close()
    
    /// Check if the connection is active
    var isActive: Bool { get }
}

// MARK: - Base Connection Class

/// Abstract base class for connections with common functionality
///
/// Note: Marked `@unchecked Sendable` because mutable state (`onMessage`, `_isActive`)
/// is protected by the subclass's synchronization mechanism.
/// Safety invariant: Subclasses must ensure thread-safe access to these properties.
open class BaseNativeRPCConnection: NativeRPCConnection, @unchecked Sendable {
    
    public let id: String
    public var onMessage: ((Data) -> Void)?
    
    private var _isActive: Bool = true
    public var isActive: Bool { _isActive }
    
    public init(id: String = UUID().uuidString) {
        self.id = id
    }
    
    open func send(_ data: Data) {
        fatalError("Subclass must override send(_:)")
    }
    
    open func close() {
        _isActive = false
        onMessage = nil
    }
    
    /// Helper to decode received message and invoke callback.
    /// Subclasses should call this when receiving data from the client.
    public func handleReceivedData(_ data: Data) {
        guard _isActive else { return }
        onMessage?(data)
    }
    
    /// Helper to decode received string and invoke callback.
    /// Subclasses should call this when receiving string data from the client.
    public func handleReceivedString(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        handleReceivedData(data)
    }
}

// MARK: - Callback-based Connection

/// A simple connection implementation using callbacks.
/// Useful for testing or custom integration scenarios.
///
/// Note: Marked `@unchecked Sendable` because mutable state is protected
/// by usage patterns (callbacks set once, state transitions are unidirectional).
/// Safety invariant: `close()` is only called once, and no sends after close.
public final class CallbackConnection: NativeRPCConnection, @unchecked Sendable {
    
    public let id: String
    public var onMessage: ((Data) -> Void)?
    
    private let sendHandler: (Data) -> Void
    private var _isActive: Bool = true
    public var isActive: Bool { _isActive }
    
    public init(
        id: String = UUID().uuidString,
        sendHandler: @escaping (Data) -> Void
    ) {
        self.id = id
        self.sendHandler = sendHandler
    }
    
    public func send(_ data: Data) {
        guard _isActive else { return }
        sendHandler(data)
    }
    
    public func close() {
        _isActive = false
        onMessage = nil
    }
    
    /// Call this to simulate receiving a message from the client
    public func receive(_ data: Data) {
        guard _isActive else { return }
        onMessage?(data)
    }
    
    /// Call this to simulate receiving a string message from the client
    public func receive(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        receive(data)
    }
}

// MARK: - In-Memory Connection Pair (for testing)

/// Creates a pair of connected connections for testing purposes.
/// Messages sent on one side are received on the other.
public final class InMemoryConnectionPair {
    
    public let client: CallbackConnection
    public let server: CallbackConnection
    
    public init() {
        var clientRef: CallbackConnection?
        var serverRef: CallbackConnection?
        
        client = CallbackConnection(id: "client") { data in
            serverRef?.receive(data)
        }
        
        server = CallbackConnection(id: "server") { data in
            clientRef?.receive(data)
        }
        
        clientRef = client
        serverRef = server
    }
}
