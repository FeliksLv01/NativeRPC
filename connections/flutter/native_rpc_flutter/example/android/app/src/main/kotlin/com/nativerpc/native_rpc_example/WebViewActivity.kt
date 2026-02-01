package com.nativerpc.native_rpc_example

import android.annotation.SuppressLint
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.itoken.team.nativerpc.webview.WebViewNativeRPCBridge

/**
 * An activity that displays a WebView connected to NativeRPC.
 *
 * This page loads the web demo (React + Vite) and connects it to the same
 * CounterService that the Flutter app uses.
 *
 * ## Usage
 * 1. Start the web demo: `cd examples/web-counter && pnpm dev`
 * 2. Open this activity from Flutter via MethodChannel
 * 3. The web page can call native services through NativeRPC
 *
 * ## Android Emulator
 * Use http://10.0.2.2:5173 to connect to host's localhost
 */
class WebViewActivity : AppCompatActivity() {
    
    companion object {
        const val EXTRA_URL = "url"
        const val DEFAULT_URL = "http://10.0.2.2:5173"
    }
    
    private lateinit var webView: WebView
    private var bridge: WebViewNativeRPCBridge? = null
    
    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable ActionBar with back button
        supportActionBar?.setDisplayHomeAsUpEnabled(true)
        supportActionBar?.title = "Web Demo"
        
        // Create WebView
        webView = WebView(this).apply {
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowContentAccess = true
                allowFileAccess = false
            }
        }
        setContentView(webView)
        
        // Set up WebView client for error handling
        setupWebViewClient()
        
        // Set up NativeRPC bridge
        setupNativeRPC()
        
        // Load the web demo
        loadWebDemo()
    }
    
    private fun setupWebViewClient() {
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                android.util.Log.d("WebViewActivity", "Page finished loading: $url")
            }
            
            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                super.onReceivedError(view, request, error)
                
                // Only handle main frame errors
                if (request?.isForMainFrame == true) {
                    val errorMessage = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                        error?.description?.toString() ?: "Unknown error"
                    } else {
                        "Failed to load page"
                    }
                    
                    android.util.Log.e("WebViewActivity", "Page load error: $errorMessage")
                    showError("Cannot connect to web demo.\n\nMake sure it's running:\ncd examples/web-counter && pnpm dev")
                }
            }
        }
    }
    
    private fun setupNativeRPC() {
        // Create and attach bridge - this connects to NativeRPCServiceCenter
        // which already has CounterService registered from MainActivity
        bridge = WebViewNativeRPCBridge(webView).apply {
            debugEnabled = true
            attach()
        }
        
        android.util.Log.d("WebViewActivity", "NativeRPC bridge attached")
    }
    
    private fun loadWebDemo() {
        val url = intent.getStringExtra(EXTRA_URL) ?: DEFAULT_URL
        android.util.Log.d("WebViewActivity", "Loading: $url")
        webView.loadUrl(url)
    }
    
    private fun showError(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show()
    }
    
    // MARK: - Menu
    
    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menu?.add(Menu.NONE, 1, Menu.NONE, "Reload")?.apply {
            setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
        }
        return true
    }
    
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                finish()
                true
            }
            1 -> {
                webView.reload()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
    
    // MARK: - Back button handling
    
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }
    
    // MARK: - Cleanup
    
    override fun onDestroy() {
        // Detach bridge - this closes the connection and cleans up service instances
        bridge?.detach()
        bridge = null
        
        // Clean up WebView
        webView.stopLoading()
        webView.destroy()
        
        android.util.Log.d("WebViewActivity", "Cleaned up")
        super.onDestroy()
    }
}
