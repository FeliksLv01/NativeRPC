package com.example.flutter_counter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.itoken.team.nativerpc.core.NativeRPCHost
import com.itoken.team.nativerpc.connection.FlutterMethodChannelConnection

class MainActivity : FlutterActivity() {
    private var rpcHost: NativeRPCHost? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize NativeRPC
        setupNativeRPC(flutterEngine)
    }
    
    private fun setupNativeRPC(flutterEngine: FlutterEngine) {
        // Create host and register services
        val host = NativeRPCHost()
        host.register(CounterService())
        
        // Create and add MethodChannel connection
        val connection = FlutterMethodChannelConnection(
            binaryMessenger = flutterEngine.dartExecutor.binaryMessenger,
            channelName = "native_rpc"
        )
        host.addConnection(connection)
        
        this.rpcHost = host
    }
}
