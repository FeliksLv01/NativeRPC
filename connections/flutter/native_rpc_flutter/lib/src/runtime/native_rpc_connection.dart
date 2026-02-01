// native_rpc_connection.dart
// NativeRPC v2
//
// Connection interface

abstract class NativeRPCConnection {
  /// Unique identifier for this connection
  String get id;

  /// Whether the connection is active
  bool get isActive;

  /// Stream of incoming messages (JSON strings)
  Stream<String> get onMessage;

  /// Send a message to native
  ///
  /// Returns a response string if synchronous (MethodChannel), otherwise null.
  Future<String?> send(String message);

  /// Close the connection
  Future<void> close();

  /// Ping the native side
  Future<bool> ping();
}
