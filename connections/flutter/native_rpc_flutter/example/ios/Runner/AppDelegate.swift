import Flutter
import UIKit
import native_rpc

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register NativeRPC services
    NativeRpcPlugin.registerService(CounterService())
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
