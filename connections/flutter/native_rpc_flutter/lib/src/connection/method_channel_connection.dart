// method_channel_connection.dart
// NativeRPC v2
//
// MethodChannel connection implementation for Flutter

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../runtime/native_rpc_connection.dart';

/// Connection implementation that bridges NativeRPC with Flutter's MethodChannel.
///
/// Usage:
/// ```dart
/// final connection = MethodChannelConnection(
///   channelName: 'com.example.nativerpc',
/// );
///
/// final client = NativeRPCClient(connection: connection);
/// ```
class MethodChannelConnection implements NativeRPCConnection {
  @override
  final String id;

  /// The MethodChannel used for communication
  final MethodChannel channel;

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  bool _isActive = true;

  /// Create a new MethodChannel connection.
  ///
  /// [channelName] - The name of the MethodChannel to use
  /// [id] - Optional unique identifier for this connection
  MethodChannelConnection({required String channelName, String? id})
      : id = id ?? 'flutter-${DateTime.now().millisecondsSinceEpoch}',
        channel = MethodChannel(channelName) {
    _setupMethodCallHandler();
  }

  /// Create from an existing MethodChannel
  MethodChannelConnection.fromChannel({required this.channel, String? id})
      : id = id ?? 'flutter-${DateTime.now().millisecondsSinceEpoch}' {
    _setupMethodCallHandler();
  }

  void _setupMethodCallHandler() {
    channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (!_isActive) return null;

    switch (call.method) {
      case 'event':
        // Handle incoming event from native
        final eventData = call.arguments as String?;
        if (eventData != null) {
          _messageController.add(eventData);
        }
        return null;

      case 'ping':
        return 'pong';

      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
    }
  }

  @override
  bool get isActive => _isActive;

  @override
  Stream<String> get onMessage => _messageController.stream;

  @override
  Future<String?> send(String message) async {
    if (!_isActive) return null;

    try {
      // Send via MethodChannel's 'rpc' method
      final result = await channel.invokeMethod<String>('rpc', message);
      return result;
    } on PlatformException catch (e) {
      // Convert platform exception to RPC error response format
      final errorResponse = {
        'id': _extractRequestId(message) ?? 'unknown',
        'type': 'error',
        'error': {
          'code': e.code,
          'message': e.message ?? 'Unknown platform error',
          'details': e.details,
        },
      };
      return jsonEncode(errorResponse);
    }
  }

  String? _extractRequestId(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      return json['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    if (!_isActive) return;
    _isActive = false;

    channel.setMethodCallHandler(null);
    await _messageController.close();
  }

  @override
  Future<bool> ping() async {
    if (!_isActive) return false;

    try {
      final result = await channel.invokeMethod<String>('ping');
      return result == 'pong';
    } catch (_) {
      return false;
    }
  }
}

/// Connection using EventChannel for one-way event streaming from native.
/// Use this when you only need to receive events without making RPC calls.
class EventChannelConnection implements NativeRPCConnection {
  @override
  final String id;

  /// The EventChannel used for receiving events
  final EventChannel eventChannel;

  /// Optional MethodChannel for sending messages
  final MethodChannel? methodChannel;

  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  StreamSubscription<dynamic>? _eventSubscription;
  bool _isActive = true;

  EventChannelConnection({
    required String eventChannelName,
    String? methodChannelName,
    String? id,
  })  : id = id ?? 'flutter-event-${DateTime.now().millisecondsSinceEpoch}',
        eventChannel = EventChannel(eventChannelName),
        methodChannel = methodChannelName != null
            ? MethodChannel(methodChannelName)
            : null {
    _setupEventListener();
  }

  void _setupEventListener() {
    _eventSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String && _isActive) {
          _messageController.add(event);
        }
      },
      onError: (dynamic error) {
        print('[NativeRPC] EventChannel error: $error');
      },
    );
  }

  @override
  bool get isActive => _isActive;

  @override
  Stream<String> get onMessage => _messageController.stream;

  @override
  Future<String?> send(String message) async {
    if (!_isActive) return null;

    if (methodChannel == null) {
      throw UnsupportedError(
        'EventChannelConnection does not support sending without a MethodChannel',
      );
    }

    try {
      return await methodChannel!.invokeMethod<String>('rpc', message);
    } on PlatformException catch (e) {
      final errorResponse = {
        'id': 'unknown',
        'type': 'error',
        'error': {
          'code': e.code,
          'message': e.message ?? 'Unknown platform error',
        },
      };
      return jsonEncode(errorResponse);
    }
  }

  @override
  Future<void> close() async {
    if (!_isActive) return;
    _isActive = false;

    await _eventSubscription?.cancel();
    await _messageController.close();
  }

  @override
  Future<bool> ping() async => _isActive;
}
