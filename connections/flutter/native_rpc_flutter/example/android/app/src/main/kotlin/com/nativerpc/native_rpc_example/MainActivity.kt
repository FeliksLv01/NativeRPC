package com.nativerpc.native_rpc_example

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.itoken.team.nativerpc.NativeRpcPlugin

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val WEBVIEW_CHANNEL = "com.nativerpc.example/webview"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register NativeRPC services
        NativeRpcPlugin.registerService(CounterService())
        
        // Set up MethodChannel for opening WebView
        setupWebViewChannel(flutterEngine)
    }
    
    private fun setupWebViewChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEBVIEW_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWebView" -> {
                    openWebViewActivity(call.arguments, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun openWebViewActivity(arguments: Any?, result: MethodChannel.Result) {
        val intent = Intent(this, WebViewActivity::class.java)
        
        // Optional: Set custom URL from arguments
        if (arguments is Map<*, *>) {
            val url = arguments["url"] as? String
            if (url != null) {
                intent.putExtra(WebViewActivity.EXTRA_URL, url)
            }
        }
        
        startActivity(intent)
        result.success(null)
    }
}
