import Flutter
import UIKit
import NativeRPCKit
import native_rpc_flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register NativeRPC services (by type, not instance)
    NativeRpcPlugin.register(CounterService.self)
    
    // Set up connection
    if let controller = window?.rootViewController as? FlutterViewController {
      NativeRpcPlugin.setupConnection(with: controller)
      
      // Set up MethodChannel for opening WebView
      setupWebViewChannel(controller: controller)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupWebViewChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.nativerpc.example/webview",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self, weak controller] (call, result) in
      guard let self = self, let controller = controller else {
        result(FlutterError(code: "NO_CONTROLLER", message: "Controller deallocated", details: nil))
        return
      }
      
      switch call.method {
      case "openWebView":
        self.openWebViewPage(controller: controller, arguments: call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func openWebViewPage(controller: FlutterViewController, arguments: Any?, result: @escaping FlutterResult) {
    // Create WebViewPage
    let webViewPage = WebViewPage()
    
    // Optional: Set custom URL from arguments
    if let args = arguments as? [String: Any], let url = args["url"] as? String {
      webViewPage.urlString = url
    }
    
    // Wrap in navigation controller for close button
    let navController = UINavigationController(rootViewController: webViewPage)
    navController.modalPresentationStyle = .fullScreen
    
    // Present
    controller.present(navController, animated: true) {
      result(nil)
    }
  }
}
