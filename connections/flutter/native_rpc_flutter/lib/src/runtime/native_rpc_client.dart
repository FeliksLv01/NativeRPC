// native_rpc_client.dart
// NativeRPC v2
//
// RPC client for Flutter using simplified JSON-RPC 2.0 protocol

import 'dart:async';
import 'dart:convert';

import 'native_rpc_connection.dart';
import 'native_rpc_message.dart';

/// Callback type for event handlers
typedef EventHandler = void Function(dynamic data);

/// The NativeRPC client for Flutter.
///
/// Protocol: Simplified JSON-RPC 2.0 (without jsonrpc field)
///
/// Usage:
/// ```dart
/// final client = NativeRPCClient(connection: connection);
///
/// // Call a method
/// final result = await client.call('counter.increment', {'step': 1});
///
/// // Subscribe to events
/// final subscription = client.subscribe('counter.countChanged', (data) {
///   print('Count changed: $data');
/// });
///
/// // Unsubscribe later
/// await subscription.cancel();
/// ```
class NativeRPCClient {
  /// The connection to native
  final NativeRPCConnection connection;

  /// Timeout for RPC calls
  final Duration timeout;

  /// Pending request completers by request ID
  final Map<String, Completer<NativeRPCResponse>> _pendingRequests = {};

  /// Event subscriptions by "service.event" key
  final Map<String, Set<EventHandler>> _eventHandlers = {};

  /// Subscription to connection messages
  StreamSubscription<String>? _messageSubscription;

  /// Whether the client has been disposed
  bool _disposed = false;

  NativeRPCClient({
    required this.connection,
    this.timeout = const Duration(seconds: 30),
  }) {
    _setupMessageHandler();
  }

  void _setupMessageHandler() {
    _messageSubscription = connection.onMessage.listen(_handleMessage);
  }

  void _handleMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;

      // Check if this is a notification (no id) or response (has id)
      if (!json.containsKey('id')) {
        // It's a notification (event)
        _handleNotification(NativeRPCNotification.fromJson(json));
      } else {
        // It's a response
        _handleResponse(NativeRPCResponse.fromJson(json));
      }
    } catch (e) {
      print('[NativeRPC] Error handling message: $e');
    }
  }

  void _handleResponse(NativeRPCResponse response) {
    final completer = _pendingRequests.remove(response.id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _handleNotification(NativeRPCNotification notification) {
    // notification.method is "service.event" format
    final handlers = _eventHandlers[notification.method];
    if (handlers != null) {
      for (final handler in handlers) {
        try {
          handler(notification.params);
        } catch (e) {
          print('[NativeRPC] Error in event handler: $e');
        }
      }
    }
  }

  /// Call a method on a service
  ///
  /// [method] - Method in format "service.method"
  /// [params] - Optional parameters
  ///
  /// Returns the result data on success, throws [NativeRPCError] on failure.
  ///
  /// Protocol:
  /// ```json
  /// Request:  {"id": "1", "method": "counter.increment", "params": {"step": 1}}
  /// Response: {"id": "1", "result": 42}
  /// Error:    {"id": "1", "error": {"code": -32601, "message": "Method not found"}}
  /// ```
  Future<T> call<T>(String method, [Map<String, dynamic>? params]) async {
    _checkDisposed();

    final request = NativeRPCRequest(method: method, params: params);

    final completer = Completer<NativeRPCResponse>();
    _pendingRequests[request.id] = completer;

    try {
      final responseStr = await connection.send(request.toJsonString());

      if (responseStr != null) {
        final response = NativeRPCResponse.fromJsonString(responseStr);
        _pendingRequests.remove(request.id);

        if (response.isError && response.error != null) {
          throw response.error!;
        }

        return response.result as T;
      }

      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(request.id);
          throw NativeRPCError.timeout('Method call $method timed out');
        },
      );

      if (response.isError && response.error != null) {
        throw response.error!;
      }

      return response.result as T;
    } catch (e) {
      _pendingRequests.remove(request.id);
      rethrow;
    }
  }

  /// Subscribe to an event
  ///
  /// [event] - Event in format "service.event"
  /// [handler] - Callback for event data
  ///
  /// Protocol:
  /// ```json
  /// Subscribe: {"id": "1", "method": "rpc.subscribe", "params": {"event": "counter.countChanged"}}
  /// Event:     {"method": "counter.countChanged", "params": {"count": 42}}
  /// ```
  Future<NativeRPCEventSubscription> subscribe(
    String event,
    EventHandler handler,
  ) async {
    _checkDisposed();

    final handlers = _eventHandlers.putIfAbsent(event, () => {});
    final isFirstSubscriber = handlers.isEmpty;
    handlers.add(handler);

    if (isFirstSubscriber) {
      final request = NativeRPCSubscribeRequest(event: event);

      try {
        await connection.send(request.toJsonString());
      } catch (e) {
        handlers.remove(handler);
        if (handlers.isEmpty) {
          _eventHandlers.remove(event);
        }
        rethrow;
      }
    }

    return NativeRPCEventSubscription._(
      client: this,
      event: event,
      handler: handler,
    );
  }

  /// Subscribe to an event and return a Stream.
  ///
  /// This is a more idiomatic Dart API that returns a broadcast Stream.
  /// The subscription is automatically managed - it subscribes when the first
  /// listener is added and unsubscribes when the last listener is removed.
  Stream<T> subscribeStream<T>(String event) {
    _checkDisposed();

    StreamController<T>? controllerRef;
    EventHandler? handlerRef;

    final controller = StreamController<T>.broadcast(
      onListen: () async {
        final handler = (dynamic data) {
          final ctrl = controllerRef;
          if (ctrl != null && !ctrl.isClosed) {
            ctrl.add(data as T);
          }
        };
        handlerRef = handler;

        final handlers = _eventHandlers.putIfAbsent(event, () => {});
        final isFirstSubscriber = handlers.isEmpty;
        handlers.add(handler);

        if (isFirstSubscriber) {
          final request = NativeRPCSubscribeRequest(event: event);

          try {
            await connection.send(request.toJsonString());
          } catch (e) {
            handlers.remove(handler);
            if (handlers.isEmpty) {
              _eventHandlers.remove(event);
            }
            controllerRef?.addError(e);
          }
        }
      },
      onCancel: () async {
        final handler = handlerRef;
        if (handler != null) {
          await _unsubscribe(event, handler);
        }
      },
    );
    controllerRef = controller;

    return controller.stream;
  }

  /// Internal method to unsubscribe from an event
  Future<void> _unsubscribe(String event, EventHandler handler) async {
    final handlers = _eventHandlers[event];
    if (handlers == null) return;

    handlers.remove(handler);

    if (handlers.isEmpty) {
      _eventHandlers.remove(event);

      if (!_disposed) {
        final request = NativeRPCUnsubscribeRequest(event: event);

        try {
          await connection.send(request.toJsonString());
        } catch (e) {
          print('[NativeRPC] Error sending unsubscribe: $e');
        }
      }
    }
  }

  /// Ping the native side to check connection
  Future<bool> ping() async {
    _checkDisposed();
    return connection.ping();
  }

  /// Dispose the client and clean up resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          NativeRPCError.connectionError('Client disposed'),
        );
      }
    }
    _pendingRequests.clear();

    _eventHandlers.clear();

    await _messageSubscription?.cancel();
    _messageSubscription = null;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw NativeRPCError.connectionError('Client has been disposed');
    }
  }
}

/// A subscription to an event that can be cancelled
class NativeRPCEventSubscription {
  final NativeRPCClient _client;
  final String _event;
  final EventHandler _handler;
  bool _cancelled = false;

  NativeRPCEventSubscription._({
    required NativeRPCClient client,
    required String event,
    required EventHandler handler,
  })  : _client = client,
        _event = event,
        _handler = handler;

  /// Cancel the subscription
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _client._unsubscribe(_event, _handler);
  }

  /// Whether the subscription has been cancelled
  bool get isCancelled => _cancelled;
}
