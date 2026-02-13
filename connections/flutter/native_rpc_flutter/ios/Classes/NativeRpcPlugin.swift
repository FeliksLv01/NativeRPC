// NativeRpcPlugin.swift
// NativeRPC v2
//
// Flutter plugin entry point for iOS
// Uses NativeRPCServiceCenter + FlutterMethodChannelConnection architecture

import Flutter
import UIKit
import NativeRPCKit

/// NativeRPC Flutter Plugin for iOS
///
/// This plugin provides the bridge between Flutter and NativeRPC using the new
/// NativeRPCServiceCenter architecture.
///
/// ## New Architecture (v2.1)
///
/// Services are:
/// - **Registered by type** at app startup via `NativeRPCServiceCenter`
/// - **Instantiated per-connection** when first called
/// - **Destroyed** when the connection closes
///
/// ## Usage
///
/// In your AppDelegate.swift:
/// ```swift
/// import NativeRPCKit
/// import native_rpc_flutter
///
/// @main
/// @objc class AppDelegate: FlutterAppDelegate {
///   private var rpcConnection: FlutterMethodChannelConnection?
///
///   override func application(
///     _ application: UIApplication,
///     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
///   ) -> Bool {
///     GeneratedPluginRegistrant.register(with: self)
///
///     // 1. Register service types at app startup
///     NativeRPCServiceCenter.shared.register(CounterService.self)
///
///     // 2. Create connection
///     if let controller = window?.rootViewController as? FlutterViewController {
///       let channel = FlutterMethodChannel(
///         name: "native_rpc",
///         binaryMessenger: controller.binaryMessenger
///       )
///       rpcConnection = FlutterMethodChannelConnection(
///         channel: channel,
///         rootViewController: controller
///       )
///     }
///
///     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
///   }
/// }
/// ```
///
/// ## Alternative: Using NativeRpcPlugin convenience methods
///
/// ```swift
/// // Register services
/// NativeRpcPlugin.register(CounterService.self)
///
/// // Setup connection (after GeneratedPluginRegistrant.register)
/// NativeRpcPlugin.setupConnection(with: controller)
/// ```
public class NativeRpcPlugin: NSObject, FlutterPlugin {
  
  // MARK: - Static Properties
  
  private static var _connection: FlutterMethodChannelConnection?
  
  /// The current connection (if using convenience setup)
  public static var connection: FlutterMethodChannelConnection? {
    return _connection
  }
  
  // MARK: - Registration Convenience Methods
  
  /// Register a service type with the global service center.
  /// Call this before Flutter initializes, typically in your AppDelegate.
  ///
  /// - Parameter serviceType: The service type to register
  ///
  /// Example:
  /// ```swift
  /// NativeRpcPlugin.register(CounterService.self)
  /// ```
  public static func register<T: NativeRPCService>(_ serviceType: T.Type) {
    NativeRPCServiceCenter.shared.register(serviceType)
  }
  
  /// Register multiple service types at once
  ///
  /// Example:
  /// ```swift
  /// NativeRpcPlugin.register(
  ///     CounterService.self,
  ///     UserService.self
  /// )
  /// ```
  public static func register(_ serviceTypes: NativeRPCService.Type...) {
    for serviceType in serviceTypes {
      NativeRPCServiceCenter.shared.register(serviceType)
    }
  }
  
  /// Setup the NativeRPC connection with a Flutter view controller.
  /// This is a convenience method that creates the FlutterMethodChannelConnection.
  ///
  /// - Parameters:
  ///   - controller: The FlutterViewController
  ///   - channelName: The method channel name (default: "native_rpc")
  /// - Returns: The created connection
  @discardableResult
  public static func setupConnection(
    with controller: FlutterViewController,
    channelName: String = "native_rpc"
  ) -> FlutterMethodChannelConnection {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
    
    let connection = FlutterMethodChannelConnection(
      channel: channel,
      rootViewController: controller
    )
    
    _connection = connection
    return connection
  }
  
  /// Close the current connection (if using convenience setup)
  public static func closeConnection() {
    _connection?.close()
    _connection = nil
  }
  
  // MARK: - FlutterPlugin
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    // The plugin is auto-registered by Flutter
    // Actual setup happens in AppDelegate via setupConnection() or manual FlutterMethodChannelConnection
    let channel = FlutterMethodChannel(
      name: "native_rpc",
      binaryMessenger: registrar.messenger()
    )
    
    let instance = NativeRpcPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // This handles basic plugin calls
    // The actual RPC handling is done by FlutterMethodChannelConnection
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "ping":
      result("pong")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
