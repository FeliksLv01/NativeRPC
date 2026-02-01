import Flutter
import UIKit
import NativeRPCKit
import native_rpc_flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var rpcHost: NativeRPCHost?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize NativeRPC
    setupNativeRPC()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupNativeRPC() {
    // Create host and register services
    let host = NativeRPCHost()
    host.register(CounterService())
    
    // Create and add MethodChannel connection
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "native_rpc",
        binaryMessenger: controller.binaryMessenger
      )
      let connection = FlutterMethodChannelConnection(channel: channel)
      host.addConnection(connection)
    }
    
    self.rpcHost = host
  }
}
