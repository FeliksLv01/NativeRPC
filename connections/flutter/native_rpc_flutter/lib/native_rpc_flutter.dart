library native_rpc_flutter;

// Export the simple NativeRPC singleton API (recommended)
export 'src/native_rpc.dart';

// Also export the lower-level APIs for advanced use cases
export 'src/runtime/native_rpc_client.dart';
export 'src/runtime/native_rpc_connection.dart';
export 'src/runtime/native_rpc_message.dart';
export 'src/connection/method_channel_connection.dart';
