import Flutter
import UIKit

/// NativeRPC Flutter Plugin
/// 
/// This plugin simply registers the MethodChannel with Flutter.
/// The actual NativeRPCHost and services should be created and configured
/// in your AppDelegate.swift.
public class NativeRpcPlugin: NSObject, FlutterPlugin {
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Just register the plugin with Flutter
    // The actual NativeRPC setup happens in AppDelegate
    let channel = FlutterMethodChannel(
      name: "native_rpc",
      binaryMessenger: registrar.messenger()
    )
    
    let instance = NativeRpcPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The actual RPC handling is done by NativeRPCHost in AppDelegate
    // This method only needs to handle plugin lifecycle methods if any
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
