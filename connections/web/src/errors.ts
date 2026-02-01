// errors.ts
// NativeRPC Web Connection
//
// Error classes

import { NativeRPCErrorCode, NativeRPCErrorObject } from './types';

/**
 * NativeRPC Error class
 */
export class NativeRPCError extends Error {
  readonly code: number;
  readonly data?: unknown;

  constructor(code: number, message: string, data?: unknown) {
    super(message);
    this.name = 'NativeRPCError';
    this.code = code;
    this.data = data;
  }

  static fromErrorObject(error: NativeRPCErrorObject): NativeRPCError {
    return new NativeRPCError(error.code, error.message, error.data);
  }

  toJSON(): NativeRPCErrorObject {
    return {
      code: this.code,
      message: this.message,
      ...(this.data !== undefined && { data: this.data }),
    };
  }

  // Standard error constructors
  static parseError(message = 'Parse error'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.parseError, message);
  }

  static invalidRequest(message = 'Invalid request'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.invalidRequest, message);
  }

  static methodNotFound(message = 'Method not found'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.methodNotFound, message);
  }

  static invalidParams(message = 'Invalid params'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.invalidParams, message);
  }

  static internalError(message = 'Internal error'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.internalError, message);
  }

  static serviceNotFound(message = 'Service not found'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.serviceNotFound, message);
  }

  static timeout(message = 'Request timeout'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.timeout, message);
  }

  static connectionError(message = 'Connection error'): NativeRPCError {
    return new NativeRPCError(NativeRPCErrorCode.connectionError, message);
  }
}
