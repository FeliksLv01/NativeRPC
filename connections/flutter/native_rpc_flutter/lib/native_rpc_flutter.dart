library native_rpc_flutter;

// Export the NativeRPC singleton API
export 'src/native_rpc.dart';

// Export low-level types (for custom connections)
export 'src/runtime/native_rpc_connection.dart';
export 'src/runtime/native_rpc_message.dart';
export 'src/connection/method_channel_connection.dart';
