// WebViewNativeRPCBridge.swift
// NativeRPCKit
//
// WKWebView bridge that connects JavaScript to NativeRPCHost
//
// Usage:
// ```swift
// import WebKit
// import NativeRPCKit
//
// class ViewController: UIViewController {
//     let webView: WKWebView = ...
//     let rpcHost = NativeRPCHost()
//
//     override func viewDidLoad() {
//         super.viewDidLoad()
//
//         // Create and register bridge
//         let bridge = WebViewNativeRPCBridge(webView: webView, host: rpcHost)
//         bridge.attach()
//     }
// }
// ```

#if canImport(WebKit)
import Foundation
import WebKit

// MARK: - WebViewNativeRPCBridge

/// A bridge that connects JavaScript in a WKWebView to a NativeRPCHost.
///
/// The bridge:
/// - Receives JSON-RPC messages from JavaScript via WKScriptMessageHandler
/// - Forwards messages to NativeRPCHost for processing
/// - Sends responses and events back to JavaScript via evaluateJavaScript
///
/// ## JavaScript API
///
/// The bridge expects JavaScript to use this pattern:
///
/// ```javascript
/// // Send message to native
/// window.webkit.messageHandlers.nativeRPC.postMessage(jsonString);
///
/// // Receive message from native (bridge calls this)
/// window.__nativeRPCCallbacks.onMessage(jsonString);
/// ```
///
/// ## Setup
///
/// ```swift
/// let bridge = WebViewNativeRPCBridge(webView: webView, host: rpcHost)
/// bridge.attach()
///
/// // When done
/// bridge.detach()
/// ```
public final class WebViewNativeRPCBridge: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The WKWebView to bridge
    private weak var webView: WKWebView?
    
    /// The NativeRPC host
    private let host: NativeRPCHost
    
    /// Message handler name (default: "nativeRPC")
    private let handlerName: String
    
    /// The connection to the host
    private var connection: WebViewConnection?
    
    /// Debug logging enabled
    public var debugEnabled: Bool = false
    
    // MARK: - Initialization
    
    /// Create a new WebView bridge
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to bridge
    ///   - host: The NativeRPCHost to connect to
    ///   - handlerName: The JavaScript message handler name (default: "nativeRPC")
    public init(webView: WKWebView, host: NativeRPCHost, handlerName: String = "nativeRPC") {
        self.webView = webView
        self.host = host
        self.handlerName = handlerName
        super.init()
    }
    
    // MARK: - Attach/Detach
    
    /// Attach the bridge to the WebView
    ///
    /// This registers the message handler and creates the connection.
    /// Call this before loading content in the WebView.
    public func attach() {
        guard let webView = webView else { return }
        
        // Remove existing handler if any
        webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        
        // Add message handler
        webView.configuration.userContentController.add(self, name: handlerName)
        
        // Inject early script to set up callbacks and dispatch ready event
        injectBridgeReadyScript(to: webView)
        
        // Create connection
        let conn = WebViewConnection(webView: webView, debugEnabled: debugEnabled)
        self.connection = conn
        
        // Register with host
        host.addConnection(conn)
        
        log("Bridge attached with handler '\(handlerName)'")
    }
    
    /// Inject a script that dispatches the bridge ready event when executed.
    ///
    /// On iOS, we can use WKUserScript to inject code at document start,
    /// ensuring the bridge is available as early as possible.
    private func injectBridgeReadyScript(to webView: WKWebView) {
        let script = """
        (function() {
            // Set up callback container
            window.__nativeRPCCallbacks = window.__nativeRPCCallbacks || {};
            
            // Mark bridge as ready
            window.__nativeRPCBridgeReady = true;
            
            // Dispatch ready event when DOM is ready
            function dispatchReadyEvent() {
                if (window.__nativeRPCBridgeReadyEventDispatched) return;
                window.__nativeRPCBridgeReadyEventDispatched = true;
                window.dispatchEvent(new Event('nativeRPCBridgeReady'));
                console.log('[NativeRPC] Bridge ready event dispatched');
            }
            
            // Dispatch immediately if document is ready, otherwise wait
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', dispatchReadyEvent);
            } else {
                dispatchReadyEvent();
            }
        })();
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(userScript)
    }
    
    /// Manually dispatch the bridge ready event.
    ///
    /// Use this if you need to notify the page again (e.g., after navigation).
    public func dispatchBridgeReadyEvent() {
        guard let webView = webView else { return }
        
        let script = """
        (function() {
            if (window.__nativeRPCBridgeReadyEventDispatched) return;
            window.__nativeRPCBridgeReady = true;
            window.__nativeRPCBridgeReadyEventDispatched = true;
            window.dispatchEvent(new Event('nativeRPCBridgeReady'));
            console.log('[NativeRPC] Bridge ready event dispatched');
        })();
        """
        
        DispatchQueue.main.async { [weak webView] in
            webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[NativeRPC WebView] Failed to dispatch ready event: \(error)")
                }
            }
        }
    }
    
    /// Detach the bridge from the WebView
    ///
    /// This removes the message handler and disconnects from the host.
    public func detach() {
        guard let webView = webView else { return }
        
        // Remove message handler
        webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        
        // Remove connection from host
        if let conn = connection {
            host.removeConnection(conn)
            conn.close()
            self.connection = nil
        }
        
        log("Bridge detached")
    }
    
    // MARK: - WKScriptMessageHandler
    
    /// Handle incoming message from JavaScript
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == handlerName else { return }
        
        guard let jsonString = message.body as? String else {
            log("Invalid message body type: \(type(of: message.body))")
            return
        }
        
        log("Received from JS: \(jsonString)")
        
        // Forward to connection
        connection?.handleReceivedString(jsonString)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if debugEnabled {
            print("[NativeRPC WebView] \(message)")
        }
    }
}

// MARK: - WebViewConnection

/// Internal connection implementation for WKWebView.
///
/// Supports iframe routing by tracking frameId from requests and including it in responses.
///
/// Note: Marked `@unchecked Sendable` because:
/// - `webView` is only accessed on main thread
/// - `_isActive` transitions are unidirectional (true -> false)
/// - `onMessage` is set once during initialization
/// - `pendingFrameIds` uses a serial queue for thread safety
final class WebViewConnection: NativeRPCConnection, @unchecked Sendable {
    
    let id: String
    var onMessage: ((Data) -> Void)?
    
    private weak var webView: WKWebView?
    private var _isActive: Bool = true
    private let debugEnabled: Bool
    
    /// Track frameId for each request ID (for iframe support)
    private var pendingFrameIds: [String: String] = [:]
    private let lock = NSLock()
    
    var isActive: Bool { _isActive }
    
    init(webView: WKWebView, id: String = UUID().uuidString, debugEnabled: Bool = false) {
        self.webView = webView
        self.id = id
        self.debugEnabled = debugEnabled
    }
    
    /// Send data to JavaScript.
    ///
    /// If the message is a response (has "id" field), we look up the frameId
    /// that was stored when the request was received and include it in the response.
    func send(_ data: Data) {
        guard _isActive, let webView = webView else { return }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            log("Failed to encode data as UTF-8")
            return
        }
        
        // Try to inject frameId into response
        let jsonWithFrameId = injectFrameIdIntoResponse(jsonString)
        
        // Escape the JSON string for JavaScript
        let escapedJson = escapeForJavaScript(jsonWithFrameId)
        
        // Call JavaScript callback
        let script = "window.__nativeRPCCallbacks?.onMessage?.('\(escapedJson)');"
        
        log("Sending to JS: \(jsonWithFrameId)")
        
        DispatchQueue.main.async { [weak webView] in
            webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[NativeRPC WebView] JS eval error: \(error)")
                }
            }
        }
    }
    
    /// Inject the stored frameId into a response message.
    private func injectFrameIdIntoResponse(_ jsonString: String) -> String {
        guard let data = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return jsonString
        }
        
        // Check if this is a response (has "id" but not "method")
        guard let requestId = json["id"] as? String,
              json["method"] == nil else {
            return jsonString
        }
        
        // Look up and remove the stored frameId
        lock.lock()
        let frameId = pendingFrameIds.removeValue(forKey: requestId)
        lock.unlock()
        
        guard let frameId = frameId else {
            return jsonString
        }
        
        // Inject frameId into response
        json["frameId"] = frameId
        
        guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
              let modifiedString = String(data: modifiedData, encoding: .utf8) else {
            return jsonString
        }
        
        return modifiedString
    }
    
    func close() {
        _isActive = false
        onMessage = nil
        lock.lock()
        pendingFrameIds.removeAll()
        lock.unlock()
    }
    
    /// Handle received string from JavaScript.
    ///
    /// Extracts and stores frameId from the request for later response routing.
    func handleReceivedString(_ string: String) {
        guard _isActive else { return }
        
        // Extract and store frameId from request
        if let data = string.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let requestId = json["id"] as? String,
           let frameId = json["frameId"] as? String {
            lock.lock()
            pendingFrameIds[requestId] = frameId
            lock.unlock()
            log("Stored frameId '\(frameId)' for request '\(requestId)'")
        }
        
        guard let data = string.data(using: .utf8) else {
            log("Failed to encode string as UTF-8")
            return
        }
        onMessage?(data)
    }
    
    /// Escape a string for safe inclusion in JavaScript
    private func escapeForJavaScript(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "'", with: "\\'")
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        return result
    }
    
    private func log(_ message: String) {
        if debugEnabled {
            print("[NativeRPC WebView] \(message)")
        }
    }
}

// MARK: - Convenience Extension

public extension WKWebView {
    
    /// Create a NativeRPC bridge for this WebView
    ///
    /// - Parameters:
    ///   - host: The NativeRPCHost to connect to
    ///   - handlerName: The JavaScript message handler name (default: "nativeRPC")
    /// - Returns: The bridge (you must keep a strong reference to it)
    func createNativeRPCBridge(host: NativeRPCHost, handlerName: String = "nativeRPC") -> WebViewNativeRPCBridge {
        let bridge = WebViewNativeRPCBridge(webView: self, host: host, handlerName: handlerName)
        bridge.attach()
        return bridge
    }
}

#endif // canImport(WebKit)
