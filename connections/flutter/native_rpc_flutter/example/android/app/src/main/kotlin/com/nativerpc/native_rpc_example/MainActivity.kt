package com.nativerpc.native_rpc_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.itoken.team.nativerpc.NativeRpcPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register NativeRPC services
        NativeRpcPlugin.registerService(CounterService())
    }
}
