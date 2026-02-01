import 'package:flutter_test/flutter_test.dart';
import 'package:native_rpc/native_rpc.dart';
import 'package:native_rpc/native_rpc_platform_interface.dart';
import 'package:native_rpc/native_rpc_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeRpcPlatform
    with MockPlatformInterfaceMixin
    implements NativeRpcPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NativeRpcPlatform initialPlatform = NativeRpcPlatform.instance;

  test('$MethodChannelNativeRpc is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeRpc>());
  });

  test('getPlatformVersion', () async {
    NativeRpc nativeRpcPlugin = NativeRpc();
    MockNativeRpcPlatform fakePlatform = MockNativeRpcPlatform();
    NativeRpcPlatform.instance = fakePlatform;

    expect(await nativeRpcPlugin.getPlatformVersion(), '42');
  });
}
