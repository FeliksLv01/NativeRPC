// native_rpc_message.dart
// NativeRPC v2
//
// Message models for the simplified JSON-RPC 2.0 protocol (without jsonrpc field)
//
// Request:      {"id": "1", "method": "service.method", "params": {...}}
// Response:     {"id": "1", "result": ...}
// Error:        {"id": "1", "error": {"code": -32601, "message": "..."}}
// Notification: {"method": "service.event", "params": {...}}  (no id)

import 'dart:convert';

import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// JSON-RPC Request
///
/// Format: {"id": "uuid", "method": "service.method", "params": {...}}
class NativeRPCRequest {
  NativeRPCRequest({required this.method, this.params, String? id})
    : id = id ?? _uuid.v4();

  /// Unique request ID for response correlation
  final String id;

  /// Method in format "service.method"
  final String method;

  /// Optional parameters (can be object or array)
  final dynamic params;

  /// Create a request from separate service and method names
  factory NativeRPCRequest.create({
    required String service,
    required String method,
    Map<String, dynamic>? params,
    String? id,
  }) {
    return NativeRPCRequest(method: '$service.$method', params: params, id: id);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'id': id, 'method': method};
    if (params != null) {
      json['params'] = params;
    }
    return json;
  }

  String toJsonString() => jsonEncode(toJson());
}

/// JSON-RPC Response (success)
///
/// Format: {"id": "uuid", "result": ...}
class NativeRPCResponse {
  NativeRPCResponse({required this.id, this.result, this.error});

  /// The ID matching the request
  final String id;

  /// Result data (present on success)
  final dynamic result;

  /// Error info (present on failure)
  final NativeRPCError? error;

  /// Whether this is an error response
  bool get isError => error != null;

  factory NativeRPCResponse.fromJson(Map<String, dynamic> json) {
    return NativeRPCResponse(
      id: json['id'] as String? ?? 'unknown',
      result: json['result'],
      error: json.containsKey('error')
          ? NativeRPCError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  static NativeRPCResponse fromJsonString(String jsonString) {
    return NativeRPCResponse.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

/// JSON-RPC Error object
///
/// Format: {"code": -32601, "message": "Method not found", "data": {...}}
class NativeRPCError implements Exception {
  NativeRPCError({required this.code, required this.message, this.data});

  /// Numeric error code (negative for standard/server errors)
  final int code;

  /// Human-readable error message
  final String message;

  /// Optional additional error data
  final dynamic data;

  factory NativeRPCError.fromJson(Map<String, dynamic> json) {
    return NativeRPCError(
      code: json['code'] as int? ?? NativeRPCErrorCode.internalError,
      message: json['message'] as String? ?? 'Unknown error',
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'code': code, 'message': message};
    if (data != null) {
      json['data'] = data;
    }
    return json;
  }

  @override
  String toString() => 'NativeRPCError [$code]: $message';

  // Standard error constructors
  static NativeRPCError parseError([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.parseError,
    message: message ?? 'Parse error',
  );

  static NativeRPCError invalidRequest([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.invalidRequest,
    message: message ?? 'Invalid request',
  );

  static NativeRPCError methodNotFound([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.methodNotFound,
    message: message ?? 'Method not found',
  );

  static NativeRPCError invalidParams([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.invalidParams,
    message: message ?? 'Invalid params',
  );

  static NativeRPCError internalError([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.internalError,
    message: message ?? 'Internal error',
  );

  static NativeRPCError serviceNotFound([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.serviceNotFound,
    message: message ?? 'Service not found',
  );

  static NativeRPCError timeout([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.timeout,
    message: message ?? 'Request timeout',
  );

  static NativeRPCError connectionError([String? message]) => NativeRPCError(
    code: NativeRPCErrorCode.connectionError,
    message: message ?? 'Connection error',
  );
}

/// JSON-RPC 2.0 standard error codes
class NativeRPCErrorCode {
  /// Parse error - Invalid JSON was received
  static const int parseError = -32700;

  /// Invalid Request - The JSON sent is not a valid Request object
  static const int invalidRequest = -32600;

  /// Method not found - The method does not exist / is not available
  static const int methodNotFound = -32601;

  /// Invalid params - Invalid method parameter(s)
  static const int invalidParams = -32602;

  /// Internal error - Internal JSON-RPC error
  static const int internalError = -32603;

  /// Server error range: -32000 to -32099
  static const int serverErrorStart = -32000;
  static const int serverErrorEnd = -32099;

  // Custom error codes (within server error range)
  static const int serviceNotFound = -32001;
  static const int eventNotFound = -32002;
  static const int timeout = -32003;
  static const int connectionError = -32004;
}

/// JSON-RPC Notification (event from server, no id)
///
/// Format: {"method": "service.event", "params": {...}}
class NativeRPCNotification {
  NativeRPCNotification({required this.method, this.params});

  /// Method/event name in format "service.event"
  final String method;

  /// Event data
  final dynamic params;

  /// Get service name from method
  String get service {
    final parts = method.split('.');
    if (parts.length >= 2) {
      return parts.sublist(0, parts.length - 1).join('.');
    }
    return method;
  }

  /// Get event name from method
  String get event {
    final parts = method.split('.');
    return parts.isNotEmpty ? parts.last : method;
  }

  factory NativeRPCNotification.fromJson(Map<String, dynamic> json) {
    return NativeRPCNotification(
      method: json['method'] as String? ?? 'unknown',
      params: json['params'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'method': method};
    if (params != null) {
      json['params'] = params;
    }
    return json;
  }

  String toJsonString() => jsonEncode(toJson());
}

/// Subscribe request using "rpc.subscribe" method
///
/// Format: {"id": "uuid", "method": "rpc.subscribe", "params": {"event": "service.event"}}
class NativeRPCSubscribeRequest {
  NativeRPCSubscribeRequest({required this.event, String? id})
    : id = id ?? _uuid.v4();

  final String id;
  final String event;

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': 'rpc.subscribe',
    'params': {'event': event},
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Unsubscribe request using "rpc.unsubscribe" method
///
/// Format: {"id": "uuid", "method": "rpc.unsubscribe", "params": {"event": "service.event"}}
class NativeRPCUnsubscribeRequest {
  NativeRPCUnsubscribeRequest({required this.event, String? id})
    : id = id ?? _uuid.v4();

  final String id;
  final String event;

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': 'rpc.unsubscribe',
    'params': {'event': event},
  };

  String toJsonString() => jsonEncode(toJson());
}
