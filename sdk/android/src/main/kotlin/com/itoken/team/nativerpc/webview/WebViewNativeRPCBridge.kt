// WebViewNativeRPCBridge.kt
// NativeRPCKit v2.1
//
// Android WebView bridge that connects JavaScript to NativeRPC
// Uses NativeRPCServiceCenter architecture
//
// Usage:
// ```kotlin
// import android.webkit.WebView
// import com.itoken.team.nativerpc.core.NativeRPCServiceCenter
// import com.itoken.team.nativerpc.webview.WebViewNativeRPCBridge
//
// class MainActivity : AppCompatActivity() {
//     private lateinit var webView: WebView
//     private var bridge: WebViewNativeRPCBridge? = null
//
//     override fun onCreate(savedInstanceState: Bundle?) {
//         super.onCreate(savedInstanceState)
//
//         // 1. Register services at app startup
//         NativeRPCServiceCenter.register(CounterService.Factory)
//
//         // 2. Create and attach bridge
//         bridge = WebViewNativeRPCBridge(webView)
//         bridge?.attach()
//     }
//
//     override fun onDestroy() {
//         bridge?.detach()
//         super.onDestroy()
//     }
// }
// ```

package com.itoken.team.nativerpc.webview

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import com.itoken.team.nativerpc.connection.NativeRPCConnection
import com.itoken.team.nativerpc.core.NativeRPCConnectionType
import org.json.JSONObject
import java.lang.ref.WeakReference
import java.util.concurrent.ConcurrentHashMap

/**
 * A bridge that connects JavaScript in an Android WebView to NativeRPC.
 *
 * Uses the NativeRPCServiceCenter architecture:
 * - Services are registered by factory at app startup
 * - Each bridge creates its own connection with per-connection service instances
 * - When the bridge is detached, service instances are destroyed
 *
 * The bridge:
 * - Receives JSON-RPC messages from JavaScript via @JavascriptInterface
 * - Forwards messages to the connection's stub for processing
 * - Sends responses and events back to JavaScript via evaluateJavascript
 *
 * ## JavaScript API
 *
 * The bridge expects JavaScript to use this pattern:
 *
 * ```javascript
 * // Send message to native (returns response synchronously if possible)
 * const response = window.NativeRPC.postMessage(jsonString);
 *
 * // Receive message from native (bridge calls this)
 * window.__nativeRPCCallbacks.onMessage(jsonString);
 * ```
 *
 * ## Setup
 *
 * ```kotlin
 * // 1. Register services first
 * NativeRPCServiceCenter.register(CounterService.Factory)
 *
 * // 2. Create and attach bridge
 * val bridge = WebViewNativeRPCBridge(webView)
 * bridge.attach()
 *
 * // When done
 * bridge.detach()
 * ```
 */
class WebViewNativeRPCBridge(
    webView: WebView,
    private val interfaceName: String = "NativeRPC"
) {
    
    // Use WeakReference to avoid memory leaks
    private val webViewRef: WeakReference<WebView> = WeakReference(webView)
    
    // The connection (extends NativeRPCConnection base class)
    private var connection: WebViewConnection? = null
    
    // Handler for main thread operations
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Original WebViewClient to chain with
    private var originalWebViewClient: WebViewClient? = null
    
    // Debug logging enabled
    var debugEnabled: Boolean = false
    
    /**
     * JavaScript interface exposed to the WebView
     */
    private inner class NativeRPCInterface {
        
        /**
         * Handle incoming message from JavaScript.
         * Called via window.NativeRPC.postMessage(jsonString)
         *
         * @param message The JSON-RPC message string
         * @return Response string for synchronous calls, or empty string for async
         */
        @JavascriptInterface
        fun postMessage(message: String): String {
            log("Received from JS: $message")
            
            // Forward to connection
            connection?.handleReceivedString(message)
            
            // Android JavascriptInterface can return synchronously, but we process async
            // Return empty string, response will come via callback
            return ""
        }
        
        /**
         * Ping to check if bridge is available
         */
        @JavascriptInterface
        fun ping(): String {
            return "pong"
        }
    }
    
    /**
     * Attach the bridge to the WebView.
     *
     * This adds the JavaScript interface and creates the connection.
     * Call this before loading content in the WebView.
     *
     * Note: Make sure JavaScript is enabled on the WebView:
     * ```kotlin
     * webView.settings.javaScriptEnabled = true
     * ```
     */
    fun attach() {
        val webView = webViewRef.get() ?: return
        
        // Add JavaScript interface
        webView.addJavascriptInterface(NativeRPCInterface(), interfaceName)
        
        // Create connection (uses NativeRPCServiceCenter internally via stub)
        val conn = WebViewConnection(webView, debugEnabled)
        this.connection = conn
        
        // Set up WebViewClient to dispatch ready event when page loads
        setupWebViewClient(webView)
        
        log("Bridge attached with interface '$interfaceName'")
    }
    
    /**
     * Set up a WebViewClient to dispatch the bridge ready event when a page starts loading.
     * 
     * On Android, the JavaScript interface is only available after the page starts loading,
     * so we need to notify the page when the bridge is ready.
     */
    private fun setupWebViewClient(webView: WebView) {
        // Save original client to chain calls
        originalWebViewClient = try {
            // Note: getWebViewClient() is not a public API, we can't get the original
            // If user needs to use their own WebViewClient, they should use the callback version
            null
        } catch (e: Exception) {
            null
        }
        
        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                originalWebViewClient?.onPageStarted(view, url, favicon)
                
                // Dispatch ready event after a short delay to ensure JS context is ready
                view?.let { dispatchBridgeReadyEvent(it) }
            }
            
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                originalWebViewClient?.onPageFinished(view, url)
                
                // Also dispatch on page finished to ensure it's received
                view?.let { dispatchBridgeReadyEvent(it) }
            }
        }
    }
    
    /**
     * Dispatch the bridge ready event to JavaScript.
     * 
     * This allows web pages to wait for the bridge to be available:
     * ```javascript
     * window.addEventListener('nativeRPCBridgeReady', () => {
     *   // Bridge is now available
     *   const result = await NativeRPC.call('service.method');
     * });
     * ```
     */
    fun dispatchBridgeReadyEvent(webView: WebView? = null) {
        val view = webView ?: webViewRef.get() ?: return
        
        val script = """
            (function() {
                if (window.__nativeRPCBridgeReady) return;
                window.__nativeRPCBridgeReady = true;
                window.dispatchEvent(new Event('nativeRPCBridgeReady'));
                console.log('[NativeRPC] Bridge ready event dispatched');
            })();
        """.trimIndent()
        
        mainHandler.post {
            view.evaluateJavascript(script) { _ ->
                log("Bridge ready event dispatched")
            }
        }
    }
    
    /**
     * Detach the bridge from the WebView.
     *
     * This removes the JavaScript interface and closes the connection,
     * which destroys all per-connection service instances.
     */
    fun detach() {
        val webView = webViewRef.get()
        
        // Remove JavaScript interface
        webView?.removeJavascriptInterface(interfaceName)
        
        // Close connection (this destroys all service instances)
        connection?.close()
        connection = null
        
        log("Bridge detached")
    }
    
    private fun log(message: String) {
        if (debugEnabled) {
            println("[NativeRPC WebView] $message")
        }
    }
}

/**
 * Internal connection implementation for Android WebView.
 * 
 * Extends NativeRPCConnection base class which provides:
 * - Automatic context and stub creation
 * - Per-connection service instance management via NativeRPCServiceCenter
 * 
 * Supports iframe routing by tracking frameId from requests and including it in responses.
 */
internal class WebViewConnection(
    webView: WebView,
    private val debugEnabled: Boolean = false
) : NativeRPCConnection(
    connectionType = NativeRPCConnectionType.WEB_VIEW
) {
    
    private val webViewRef: WeakReference<WebView> = WeakReference(webView)
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Track frameId for each request ID (for iframe support)
    private val pendingFrameIds = ConcurrentHashMap<String, String>()
    
    /**
     * Send data to JavaScript.
     * 
     * If the message is a response (has "id" field), we look up the frameId
     * that was stored when the request was received and include it in the response.
     */
    override fun send(data: String) {
        if (!isActive) return
        
        val webView = webViewRef.get() ?: return
        
        // Try to inject frameId into response
        val dataWithFrameId = injectFrameIdIntoResponse(data)
        
        // Escape the JSON string for JavaScript
        val escapedJson = escapeForJavaScript(dataWithFrameId)
        
        // Call JavaScript callback
        val script = "window.__nativeRPCCallbacks?.onMessage?.('$escapedJson');"
        
        log("Sending to JS: $dataWithFrameId")
        
        // Must run on main thread
        mainHandler.post {
            webView.evaluateJavascript(script) { result ->
                if (result != null && result != "null") {
                    log("JS eval result: $result")
                }
            }
        }
    }
    
    /**
     * Inject the stored frameId into a response message.
     */
    private fun injectFrameIdIntoResponse(data: String): String {
        return try {
            val json = JSONObject(data)
            
            // Check if this is a response (has "id" but not "method")
            if (json.has("id") && !json.has("method")) {
                val requestId = json.getString("id")
                val frameId = pendingFrameIds.remove(requestId)
                
                if (frameId != null) {
                    json.put("frameId", frameId)
                    json.toString()
                } else {
                    data
                }
            } else {
                data
            }
        } catch (e: Exception) {
            data
        }
    }
    
    /**
     * Handle received string from JavaScript.
     * 
     * Extracts and stores frameId from the request for later response routing.
     */
    fun handleReceivedString(string: String) {
        if (!isActive) return
        
        // Extract and store frameId from request
        try {
            val json = JSONObject(string)
            if (json.has("id") && json.has("frameId")) {
                val requestId = json.getString("id")
                val frameId = json.getString("frameId")
                pendingFrameIds[requestId] = frameId
                log("Stored frameId '$frameId' for request '$requestId'")
            }
        } catch (e: Exception) {
            // Ignore parse errors
        }
        
        // Forward to connection's handleReceivedData (which forwards to stub)
        handleReceivedData(string)
    }
    
    override fun close() {
        pendingFrameIds.clear()
        super.close()
    }
    
    /**
     * Escape a string for safe inclusion in JavaScript
     */
    private fun escapeForJavaScript(string: String): String {
        return string
            .replace("\\", "\\\\")
            .replace("'", "\\'")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }
    
    private fun log(message: String) {
        if (debugEnabled) {
            println("[NativeRPC WebView] $message")
        }
    }
}

/**
 * Extension function to easily create a NativeRPC bridge for a WebView.
 *
 * Note: Make sure to register services with NativeRPCServiceCenter before calling this:
 * ```kotlin
 * NativeRPCServiceCenter.register(CounterService.Factory)
 * val bridge = webView.createNativeRPCBridge()
 * ```
 */
fun WebView.createNativeRPCBridge(
    interfaceName: String = "NativeRPC"
): WebViewNativeRPCBridge {
    val bridge = WebViewNativeRPCBridge(this, interfaceName)
    bridge.attach()
    return bridge
}
