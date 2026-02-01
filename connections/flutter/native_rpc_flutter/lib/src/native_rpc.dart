// native_rpc.dart
// NativeRPC v2
//
// Simple, singleton-based NativeRPC API for Flutter
// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)
//
// Request:  {"id": "1", "method": "service.method", "params": {...}}
// Response: {"id": "1", "result": ...} or {"id": "1", "error": {"code": -32601, "message": "..."}}
// Event:    {"method": "service.event", "params": {...}}  (no id = notification)

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'runtime/native_rpc_message.dart';

// Re-export message types
export 'runtime/native_rpc_message.dart';

/// Callback type for event handlers
typedef NativeRPCEventHandler = void Function(dynamic data);

/// The main NativeRPC class - a singleton for simple RPC calls to native.
///
/// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)
///
/// Usage:
/// ```dart
/// // Initialize once (optional, auto-initializes on first use)
/// NativeRPC.init(channelName: 'native_rpc');
///
/// // Call a method
/// final result = await NativeRPC.call<int>('counter.increment');
/// final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});
///
/// // Listen to events
/// NativeRPC.on('counter.countChanged', (data) {
///   print('Count changed: ${data['count']}');
/// });
///
/// // Remove listener
/// NativeRPC.off('counter.countChanged', handler);
/// ```
class NativeRPC {
  // Singleton instance
  static NativeRPC? _instance;

  // Internal state
  final MethodChannel _channel;
  final Map<String, Set<NativeRPCEventHandler>> _eventHandlers = {};
  int _callIdCount = 0;
  bool _isActive = true;

  // Private constructor
  NativeRPC._(String channelName) : _channel = MethodChannel(channelName) {
    _setupMethodCallHandler();
  }

  /// Initialize NativeRPC with a custom channel name.
  /// If not called, auto-initializes with 'native_rpc' on first use.
  static void init({String channelName = 'native_rpc'}) {
    _instance ??= NativeRPC._(channelName);
  }

  /// Get the singleton instance, auto-initializing if needed
  static NativeRPC get _i {
    _instance ??= NativeRPC._('native_rpc');
    return _instance!;
  }

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (!_isActive) return null;

    switch (call.method) {
      case 'notification':
        // Handle incoming event notification from native (JSON-RPC notification format)
        _handleNotification(call.arguments);
        return null;
      case 'ping':
        return 'pong';
      default:
        return null;
    }
  }

  /// Handle incoming notification from native
  /// Format: {"method": "service.event", "params": {...}}
  void _handleNotification(dynamic arguments) {
    try {
      Map<String, dynamic> json;
      if (arguments is String) {
        json = jsonDecode(arguments) as Map<String, dynamic>;
      } else if (arguments is Map) {
        json = Map<String, dynamic>.from(arguments);
      } else {
        return;
      }

      // JSON-RPC notification format: method contains full path "service.event"
      final method = json['method'] as String?;
      final params = json['params'];

      if (method != null) {
        // method is already in "service.event" format
        final handlers = _eventHandlers[method];
        if (handlers != null) {
          for (final handler in handlers.toList()) {
            try {
              handler(params);
            } catch (e) {
              print('[NativeRPC] Error in event handler: $e');
            }
          }
        }
      }
    } catch (e) {
      print('[NativeRPC] Error handling notification: $e');
    }
  }

  /// Call a native method.
  ///
  /// [method] - The method in format "service.method"
  /// [params] - Optional parameters to pass to the method
  ///
  /// Protocol:
  /// ```json
  /// Request:  {"id": "1", "method": "counter.increment", "params": {"step": 1}}
  /// Response: {"id": "1", "result": 42}
  /// Error:    {"id": "1", "error": {"code": -32601, "message": "Method not found"}}
  /// ```
  ///
  /// Examples:
  /// ```dart
  /// final count = await NativeRPC.call<int>('counter.increment');
  /// final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});
  /// final user = await NativeRPC.call<Map>('user.getProfile', {'id': '123'});
  /// ```
  static Future<T> call<T>(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    return _i._call<T>(method, params);
  }

  Future<T> _call<T>(String method, Map<String, dynamic>? params) async {
    // Validate method format
    if (!method.contains('.')) {
      throw NativeRPCException(
        code: NativeRPCErrorCode.invalidRequest,
        message: 'Invalid method: $method. Expected format: "service.method"',
      );
    }

    // Create JSON-RPC request (without jsonrpc field)
    final id = '${_callIdCount++}';
    final request = <String, dynamic>{
      'id': id,
      'method': method,
    };

    // Only include params if provided
    if (params != null && params.isNotEmpty) {
      request['params'] = params;
    }

    try {
      final responseStr =
          await _channel.invokeMethod<String>('rpc', jsonEncode(request));

      if (responseStr != null) {
        final response = jsonDecode(responseStr) as Map<String, dynamic>;

        // Check for error response
        if (response.containsKey('error')) {
          final error = response['error'] as Map<String, dynamic>;
          throw NativeRPCException(
            code: error['code'] as int? ?? NativeRPCErrorCode.internalError,
            message: error['message'] as String? ?? 'Unknown error',
            data: error['data'],
          );
        }

        // Return result
        return response['result'] as T;
      }

      throw NativeRPCException(
        code: NativeRPCErrorCode.internalError,
        message: 'No response from native',
      );
    } on PlatformException catch (e) {
      throw NativeRPCException(
        code: NativeRPCErrorCode.connectionError,
        message: e.message ?? 'Platform error',
        data: e.details,
      );
    }
  }

  /// Listen to an event from native.
  ///
  /// Protocol: Subscribes via "rpc.subscribe" method, receives notifications
  /// ```json
  /// Subscribe: {"id": "sub_1", "method": "rpc.subscribe", "params": {"event": "counter.countChanged"}}
  /// Event:     {"method": "counter.countChanged", "params": {"count": 42}}
  /// ```
  ///
  /// Examples:
  /// ```dart
  /// NativeRPC.on('counter.countChanged', (data) {
  ///   print('Count: ${data['count']}');
  /// });
  /// ```
  static void on(String event, NativeRPCEventHandler handler) {
    _i._on(event, handler);
  }

  void _on(String event, NativeRPCEventHandler handler) {
    // Validate event format
    if (!event.contains('.')) {
      throw ArgumentError(
          'Invalid event: $event. Expected format: "service.event"');
    }

    final handlers = _eventHandlers.putIfAbsent(event, () => {});
    final isFirstSubscriber = handlers.isEmpty;
    handlers.add(handler);

    // Notify native that we're subscribing to this event
    if (isFirstSubscriber) {
      final id = 'sub_${_callIdCount++}';
      final request = {
        'id': id,
        'method': 'rpc.subscribe',
        'params': {'event': event},
      };
      _channel.invokeMethod('rpc', jsonEncode(request)).catchError((e) {
        print('[NativeRPC] Error subscribing to event: $e');
      });
    }
  }

  /// Remove an event listener.
  ///
  /// Protocol: Unsubscribes via "rpc.unsubscribe" method
  /// ```json
  /// {"id": "unsub_1", "method": "rpc.unsubscribe", "params": {"event": "counter.countChanged"}}
  /// ```
  ///
  /// Examples:
  /// ```dart
  /// NativeRPC.off('counter.countChanged', myHandler);
  /// ```
  static void off(String event, NativeRPCEventHandler handler) {
    _i._off(event, handler);
  }

  void _off(String event, NativeRPCEventHandler handler) {
    final handlers = _eventHandlers[event];
    if (handlers == null) return;

    handlers.remove(handler);

    // Notify native when last subscriber is removed
    if (handlers.isEmpty) {
      _eventHandlers.remove(event);
      final id = 'unsub_${_callIdCount++}';
      final request = {
        'id': id,
        'method': 'rpc.unsubscribe',
        'params': {'event': event},
      };
      _channel.invokeMethod('rpc', jsonEncode(request)).catchError((e) {
        print('[NativeRPC] Error unsubscribing from event: $e');
      });
    }
  }

  /// Get a stream of events from native.
  ///
  /// This is an alternative to [on]/[off] that provides a Stream interface.
  /// The stream automatically subscribes when listened to and unsubscribes
  /// when cancelled.
  ///
  /// Examples:
  /// ```dart
  /// final subscription = NativeRPC.stream('counter.countChanged').listen((data) {
  ///   print('Count: ${data['count']}');
  /// });
  ///
  /// // Later, cancel the subscription
  /// subscription.cancel();
  /// ```
  static Stream<dynamic> stream(String event) {
    return _i._stream(event);
  }

  Stream<dynamic> _stream(String event) {
    // Validate event format
    if (!event.contains('.')) {
      throw ArgumentError(
          'Invalid event: $event. Expected format: "service.event"');
    }

    StreamController<dynamic>? controllerRef;
    NativeRPCEventHandler? handlerRef;

    final controller = StreamController<dynamic>(
      onListen: () {
        final handler = (dynamic data) {
          final ctrl = controllerRef;
          if (ctrl != null && !ctrl.isClosed) {
            ctrl.add(data);
          }
        };
        handlerRef = handler;
        _on(event, handler);
      },
      onCancel: () {
        final handler = handlerRef;
        if (handler != null) {
          _off(event, handler);
        }
        controllerRef?.close();
      },
    );
    controllerRef = controller;

    return controller.stream;
  }

  /// Check connection to native
  static Future<bool> ping() async {
    try {
      final result = await _i._channel.invokeMethod<String>('ping');
      return result == 'pong';
    } catch (_) {
      return false;
    }
  }

  /// Dispose the NativeRPC instance (rarely needed)
  static void dispose() {
    final instance = _instance;
    if (instance != null) {
      instance._isActive = false;
      instance._channel.setMethodCallHandler(null);
      instance._eventHandlers.clear();
      _instance = null;
    }
  }
}

/// Exception thrown when a NativeRPC call fails
class NativeRPCException implements Exception {
  /// JSON-RPC error code (negative number for standard/server errors)
  final int code;

  /// Human-readable error message
  final String message;

  /// Optional additional error data
  final dynamic data;

  NativeRPCException({
    required this.code,
    required this.message,
    this.data,
  });

  @override
  String toString() => 'NativeRPCException [$code]: $message';

  /// Check if this is a standard JSON-RPC error
  bool get isStandardError => code <= -32600 && code >= -32700;

  /// Check if this is a server error
  bool get isServerError =>
      code <= NativeRPCErrorCode.serverErrorStart &&
      code >= NativeRPCErrorCode.serverErrorEnd;
}
