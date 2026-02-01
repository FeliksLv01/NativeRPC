// WebViewNativeRPCBridge.swift
// NativeRPCKit
//
// WKWebView connection that enables JavaScript to call native services
//
// Usage:
// ```swift
// import WebKit
// import NativeRPCKit
//
// // 1. Register services at app startup
// NativeRPCServiceCenter.shared.register(MyService.self)
//
// // 2. Create WebView connection
// let connection = WebViewNativeRPCConnection(webView: webView)
//
// // 3. When done
// connection.close()
// ```

#if canImport(WebKit)
import Foundation
import WebKit

// MARK: - WebViewNativeRPCConnection

/// A connection that bridges JavaScript in a WKWebView to native RPC services.
///
/// ## Simple Usage
///
/// ```swift
/// // Register services first
/// NativeRPCServiceCenter.shared.register(MyService.self)
///
/// // Create connection (auto-attaches to WebView)
/// let connection = WebViewNativeRPCConnection(webView: webView)
///
/// // When done
/// connection.close()
/// ```
///
/// ## JavaScript API
///
/// The bridge expects JavaScript to use this pattern:
///
/// ```javascript
/// // Send message to native
/// window.webkit.messageHandlers.nativeRPC.postMessage(jsonString);
///
/// // Receive message from native (set up callback first)
/// window.__nativeRPCCallbacks = {
///     onMessage: function(jsonString) {
///         // Handle response or event
///     }
/// };
/// ```
///
/// ## Iframe Support
///
/// The connection tracks `frameId` from requests and includes it in responses,
/// enabling proper routing to iframes.
public final class WebViewNativeRPCConnection: NativeRPCConnection, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The WKWebView this connection is bridged to
    private weak var webView: WKWebView?
    
    /// Message handler name (default: "nativeRPC")
    private let handlerName: String
    
    /// Debug logging enabled
    public var debugEnabled: Bool = false
    
    /// The script message handler (must be NSObject for WKWebView)
    private var messageHandler: WebViewMessageHandler?
    
    /// Track frameId for each request ID (for iframe support)
    private var pendingFrameIds: [String: String] = [:]
    private let frameIdLock = NSLock()
    
    // MARK: - Initialization
    
    /// Create a new WebView connection.
    ///
    /// The connection automatically attaches to the WebView and is ready to use.
    ///
    /// - Parameters:
    ///   - webView: The WKWebView to bridge
    ///   - handlerName: The JavaScript message handler name (default: "nativeRPC")
    ///   - rootViewController: Optional root view controller for UI operations
    public init(
        webView: WKWebView,
        handlerName: String = "nativeRPC",
        rootViewController: NativeViewController? = nil
    ) {
        self.webView = webView
        self.handlerName = handlerName
        
        super.init(
            connectionType: .webView,
            rootView: webView,
            rootViewController: rootViewController
        )
        
        // Attach to WebView on main actor
        // We're already on main thread (WKWebView requires it), but need to satisfy Swift Concurrency
        MainActor.assumeIsolated {
            attach()
        }
    }
    
    // MARK: - Attach/Detach
    
    /// Attach the bridge to the WebView (called automatically in init)
    @MainActor
    private func attach() {
        guard let webView = webView else { return }
        
        // Create message handler
        let handler = WebViewMessageHandler { [weak self] jsonString in
            self?.onMessageReceived(jsonString)
        }
        self.messageHandler = handler
        
        // Remove existing handler if any
        webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
        
        // Add message handler
        webView.configuration.userContentController.add(handler, name: handlerName)
        
        // Inject early script to set up callbacks and dispatch ready event
        injectBridgeReadyScript(to: webView)
        
        log("WebView connection attached with handler '\(handlerName)'")
    }
    
    /// Handle message received from JavaScript
    private func onMessageReceived(_ jsonString: String) {
        log("Received from JS: \(jsonString)")
        
        // Extract and store frameId from request (for iframe support)
        storeFrameIdIfPresent(jsonString)
        
        // Forward to stub via handleReceivedString
        handleReceivedString(jsonString)
    }
    
    /// Inject a script that dispatches the bridge ready event when executed.
    @MainActor
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
    
    // MARK: - Send (Override)
    
    /// Send a JSON string to JavaScript.
    ///
    /// If the message is a response (has "id" field), we look up the frameId
    /// that was stored when the request was received and include it in the response.
    public override func send(_ jsonString: String) {
        guard isActive else { return }
        
        // Try to inject frameId into response
        let jsonWithFrameId = injectFrameIdIntoResponse(jsonString)
        
        // Escape the JSON string for JavaScript
        let escapedJson = escapeForJavaScript(jsonWithFrameId)
        
        // Call JavaScript callback
        let script = "window.__nativeRPCCallbacks?.onMessage?.('\(escapedJson)');"
        
        log("Sending to JS: \(jsonWithFrameId)")
        
        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(script) { _, error in
                if let error = error {
                    print("[NativeRPC WebView] JS eval error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Close (Override)
    
    /// Close the connection and detach from WebView.
    public override func close() {
        // Detach from WebView
        if let webView = webView {
            DispatchQueue.main.async { [weak webView, handlerName] in
                webView?.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
            }
        }
        
        // Clear message handler
        messageHandler = nil
        
        // Clear frameId tracking
        frameIdLock.lock()
        pendingFrameIds.removeAll()
        frameIdLock.unlock()
        
        // Call super to clean up stub and context
        super.close()
        
        log("WebView connection closed")
    }
    
    // MARK: - Frame ID Support (for iframes)
    
    /// Extract and store frameId from a request for later response routing.
    private func storeFrameIdIfPresent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestId = json["id"] as? String,
              let frameId = json["frameId"] as? String else {
            return
        }
        
        frameIdLock.lock()
        pendingFrameIds[requestId] = frameId
        frameIdLock.unlock()
        log("Stored frameId '\(frameId)' for request '\(requestId)'")
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
        frameIdLock.lock()
        let frameId = pendingFrameIds.removeValue(forKey: requestId)
        frameIdLock.unlock()
        
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
    
    // MARK: - Helpers
    
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

// MARK: - WebViewMessageHandler (Internal)

/// Internal NSObject-based message handler for WKWebView
private final class WebViewMessageHandler: NSObject, WKScriptMessageHandler {
    
    private let onMessage: (String) -> Void
    
    init(onMessage: @escaping (String) -> Void) {
        self.onMessage = onMessage
        super.init()
    }
    
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let jsonString = message.body as? String else {
            print("[NativeRPC WebView] Invalid message body type: \(type(of: message.body))")
            return
        }
        onMessage(jsonString)
    }
}

// MARK: - Convenience Extension

public extension WKWebView {
    
    /// Create a NativeRPC connection for this WebView.
    ///
    /// Make sure to register your services first:
    /// ```swift
    /// NativeRPCServiceCenter.shared.register(MyService.self)
    /// ```
    ///
    /// - Parameters:
    ///   - handlerName: The JavaScript message handler name (default: "nativeRPC")
    /// - Returns: The connection (keep a strong reference to it)
    func createNativeRPCConnection(handlerName: String = "nativeRPC") -> WebViewNativeRPCConnection {
        return WebViewNativeRPCConnection(webView: self, handlerName: handlerName)
    }
}

#endif // canImport(WebKit)
