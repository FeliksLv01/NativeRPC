/**
 * NativeRPC Code Generator - Validator
 * 
 * Validates service definitions before code generation.
 */

import {
  ServiceModule,
  ServiceMethod,
  ServiceEvent,
  ValueType,
  isVoidType,
  isPrimitiveType,
  isArrayType,
  isCustomType,
  isOptionalType,
  isDictionaryType,
  isEnumType,
  MethodKind,
} from '../types';

// ============================================================================
// Validation Types
// ============================================================================

export enum ValidationSeverity {
  Error = 'error',
  Warning = 'warning',
  Info = 'info',
}

export interface ValidationMessage {
  severity: ValidationSeverity;
  code: string;
  message: string;
  location?: {
    service?: string;
    method?: string;
    event?: string;
    field?: string;
  };
  suggestion?: string;
}

export interface ValidationResult {
  valid: boolean;
  messages: ValidationMessage[];
}

// ============================================================================
// Validator
// ============================================================================

export class ServiceValidator {
  private messages: ValidationMessage[] = [];
  
  /**
   * Validate a service module
   */
  validate(module: ServiceModule): ValidationResult {
    this.messages = [];
    
    // Validate service name
    this.validateServiceName(module);
    
    // Validate methods
    for (const method of module.methods) {
      this.validateMethod(method, module.name);
    }
    
    // Validate events
    for (const event of module.events) {
      this.validateEvent(event, module.name);
    }
    
    // Validate custom types
    for (const customType of module.customTypes) {
      this.validateCustomType(customType, module.name);
    }
    
    // Check for duplicate names
    this.checkDuplicateMethodNames(module);
    this.checkDuplicateEventNames(module);
    
    return {
      valid: !this.messages.some(m => m.severity === ValidationSeverity.Error),
      messages: this.messages,
    };
  }
  
  /**
   * Validate multiple modules
   */
  validateAll(modules: ServiceModule[]): ValidationResult {
    const allMessages: ValidationMessage[] = [];
    let allValid = true;
    
    for (const module of modules) {
      const result = this.validate(module);
      allMessages.push(...result.messages);
      if (!result.valid) {
        allValid = false;
      }
    }
    
    // Check for duplicate service names
    const serviceNames = new Set<string>();
    for (const module of modules) {
      const name = module.name.toLowerCase();
      if (serviceNames.has(name)) {
        allMessages.push({
          severity: ValidationSeverity.Error,
          code: 'DUPLICATE_SERVICE',
          message: `Duplicate service name: "${module.name}"`,
          location: { service: module.name },
          suggestion: 'Each service must have a unique name',
        });
        allValid = false;
      }
      serviceNames.add(name);
    }
    
    return {
      valid: allValid,
      messages: allMessages,
    };
  }
  
  // ============================================================================
  // Validation Methods
  // ============================================================================
  
  private validateServiceName(module: ServiceModule): void {
    const name = module.name;
    
    // Check for empty name
    if (!name || name.trim().length === 0) {
      this.addError('EMPTY_SERVICE_NAME', 'Service name cannot be empty', {
        service: '(unknown)',
      });
      return;
    }
    
    // Check for valid identifier
    if (!/^[A-Z][a-zA-Z0-9]*$/.test(name)) {
      this.addWarning(
        'INVALID_SERVICE_NAME',
        `Service name "${name}" should be PascalCase`,
        { service: name },
        'Use PascalCase naming (e.g., CounterService, UserService)'
      );
    }
    
    // Check if ends with Service
    if (!name.endsWith('Service')) {
      this.addInfo(
        'MISSING_SERVICE_SUFFIX',
        `Service name "${name}" does not end with "Service"`,
        { service: name },
        'Consider naming your service interface as ICounterService'
      );
    }
  }
  
  private validateMethod(method: ServiceMethod, serviceName: string): void {
    const { name, parameters, returnType, kind } = method;
    
    // Check for empty name
    if (!name || name.trim().length === 0) {
      this.addError('EMPTY_METHOD_NAME', 'Method name cannot be empty', {
        service: serviceName,
      });
      return;
    }
    
    // Check for valid identifier
    if (!/^[a-z][a-zA-Z0-9]*$/.test(name)) {
      this.addWarning(
        'INVALID_METHOD_NAME',
        `Method name "${name}" should be camelCase`,
        { service: serviceName, method: name },
        'Use camelCase naming (e.g., getValue, incrementCounter)'
      );
    }
    
    // Check for reserved names
    const reserved = ['constructor', 'prototype', 'toString', 'valueOf'];
    if (reserved.includes(name)) {
      this.addError(
        'RESERVED_METHOD_NAME',
        `Method name "${name}" is reserved`,
        { service: serviceName, method: name },
        'Choose a different method name'
      );
    }
    
    // Validate parameters
    for (const param of parameters) {
      this.validateParameter(param, name, serviceName);
    }
    
    // Validate return type
    if (returnType && !isVoidType(returnType)) {
      this.validateType(returnType, serviceName, name, 'return type');
    }
    
    // Check async methods have meaningful return
    if (kind === MethodKind.Async && returnType && isVoidType(returnType)) {
      this.addInfo(
        'ASYNC_VOID_RETURN',
        `Async method "${name}" returns void`,
        { service: serviceName, method: name },
        'Consider using a sync void method instead if no async operation is needed'
      );
    }
  }
  
  private validateParameter(
    param: { name: string; type: ValueType; optional: boolean },
    methodName: string,
    serviceName: string
  ): void {
    // Check for valid parameter name
    if (!/^[a-z][a-zA-Z0-9]*$/.test(param.name)) {
      this.addWarning(
        'INVALID_PARAMETER_NAME',
        `Parameter name "${param.name}" should be camelCase`,
        { service: serviceName, method: methodName, field: param.name },
        'Use camelCase naming (e.g., delayMs, userId)'
      );
    }
    
    // Validate parameter type
    this.validateType(param.type, serviceName, methodName, `parameter "${param.name}"`);
  }
  
  private validateEvent(event: ServiceEvent, serviceName: string): void {
    const { name, payloadType } = event;
    
    // Check for empty name
    if (!name || name.trim().length === 0) {
      this.addError('EMPTY_EVENT_NAME', 'Event name cannot be empty', {
        service: serviceName,
      });
      return;
    }
    
    // Check for valid identifier
    if (!/^[a-z][a-zA-Z0-9]*$/.test(name)) {
      this.addWarning(
        'INVALID_EVENT_NAME',
        `Event name "${name}" should be camelCase`,
        { service: serviceName, event: name },
        'Use camelCase naming (e.g., countChanged, userLoggedIn)'
      );
    }
    
    // Validate payload type if present
    if (payloadType && !isVoidType(payloadType)) {
      this.validateType(payloadType, serviceName, name, 'event payload');
    }
  }
  
  private validateCustomType(
    customType: { name: string; fields: Array<{ name: string; type: ValueType }> },
    serviceName: string
  ): void {
    // Check for valid type name
    if (!/^[A-Z][a-zA-Z0-9]*$/.test(customType.name)) {
      this.addWarning(
        'INVALID_TYPE_NAME',
        `Type name "${customType.name}" should be PascalCase`,
        { service: serviceName },
        'Use PascalCase naming (e.g., UserInfo, CounterResult)'
      );
    }
    
    // Check for empty types
    if (customType.fields.length === 0) {
      this.addWarning(
        'EMPTY_TYPE',
        `Type "${customType.name}" has no fields`,
        { service: serviceName },
        'Consider adding fields or using void/null instead'
      );
    }
    
    // Check for duplicate field names
    const fieldNames = new Set<string>();
    for (const field of customType.fields) {
      if (fieldNames.has(field.name)) {
        this.addError(
          'DUPLICATE_FIELD',
          `Duplicate field name "${field.name}" in type "${customType.name}"`,
          { service: serviceName, field: field.name }
        );
      }
      fieldNames.add(field.name);
    }
  }
  
  private validateType(
    type: ValueType,
    serviceName: string,
    contextName: string,
    contextDesc: string
  ): void {
    // Check for 'any' type usage
    if (isPrimitiveType(type) && type.value === 'any') {
      this.addWarning(
        'ANY_TYPE_USAGE',
        `Using 'any' type in ${contextDesc} of "${contextName}"`,
        { service: serviceName, method: contextName },
        'Consider using a specific type for better type safety'
      );
    }
    
    // Recursively validate nested types
    if (isArrayType(type)) {
      this.validateType(type.elementType, serviceName, contextName, `${contextDesc} array element`);
    }
    
    if (isOptionalType(type)) {
      this.validateType(type.wrappedType, serviceName, contextName, `${contextDesc} optional`);
    }
    
    if (isDictionaryType(type)) {
      this.validateType(type.valueType, serviceName, contextName, `${contextDesc} dictionary value`);
    }
  }
  
  private checkDuplicateMethodNames(module: ServiceModule): void {
    const names = new Set<string>();
    for (const method of module.methods) {
      if (names.has(method.name)) {
        this.addError(
          'DUPLICATE_METHOD',
          `Duplicate method name "${method.name}"`,
          { service: module.name, method: method.name }
        );
      }
      names.add(method.name);
    }
  }
  
  private checkDuplicateEventNames(module: ServiceModule): void {
    const names = new Set<string>();
    for (const event of module.events) {
      if (names.has(event.name)) {
        this.addError(
          'DUPLICATE_EVENT',
          `Duplicate event name "${event.name}"`,
          { service: module.name, event: event.name }
        );
      }
      names.add(event.name);
    }
    
    // Also check for method/event name collision
    const methodNames = new Set(module.methods.map(m => m.name));
    for (const event of module.events) {
      if (methodNames.has(event.name)) {
        this.addWarning(
          'METHOD_EVENT_COLLISION',
          `Event "${event.name}" has same name as a method`,
          { service: module.name, event: event.name },
          'Consider using different names to avoid confusion'
        );
      }
    }
  }
  
  // ============================================================================
  // Helper Methods
  // ============================================================================
  
  private addError(
    code: string,
    message: string,
    location?: ValidationMessage['location'],
    suggestion?: string
  ): void {
    this.messages.push({
      severity: ValidationSeverity.Error,
      code,
      message,
      location,
      suggestion,
    });
  }
  
  private addWarning(
    code: string,
    message: string,
    location?: ValidationMessage['location'],
    suggestion?: string
  ): void {
    this.messages.push({
      severity: ValidationSeverity.Warning,
      code,
      message,
      location,
      suggestion,
    });
  }
  
  private addInfo(
    code: string,
    message: string,
    location?: ValidationMessage['location'],
    suggestion?: string
  ): void {
    this.messages.push({
      severity: ValidationSeverity.Info,
      code,
      message,
      location,
      suggestion,
    });
  }
}

// ============================================================================
// Formatting
// ============================================================================

/**
 * Format validation messages for console output
 */
export function formatValidationMessages(messages: ValidationMessage[]): string {
  const lines: string[] = [];
  
  const errors = messages.filter(m => m.severity === ValidationSeverity.Error);
  const warnings = messages.filter(m => m.severity === ValidationSeverity.Warning);
  const infos = messages.filter(m => m.severity === ValidationSeverity.Info);
  
  if (errors.length > 0) {
    lines.push('\n❌ Errors:');
    for (const msg of errors) {
      lines.push(formatMessage(msg));
    }
  }
  
  if (warnings.length > 0) {
    lines.push('\n⚠️  Warnings:');
    for (const msg of warnings) {
      lines.push(formatMessage(msg));
    }
  }
  
  if (infos.length > 0) {
    lines.push('\nℹ️  Info:');
    for (const msg of infos) {
      lines.push(formatMessage(msg));
    }
  }
  
  if (messages.length > 0) {
    lines.push('');
    lines.push(`Summary: ${errors.length} error(s), ${warnings.length} warning(s), ${infos.length} info`);
  }
  
  return lines.join('\n');
}

function formatMessage(msg: ValidationMessage): string {
  let location = '';
  if (msg.location) {
    const parts: string[] = [];
    if (msg.location.service) parts.push(msg.location.service);
    if (msg.location.method) parts.push(msg.location.method);
    if (msg.location.event) parts.push(`event:${msg.location.event}`);
    if (msg.location.field) parts.push(msg.location.field);
    if (parts.length > 0) {
      location = ` [${parts.join('.')}]`;
    }
  }
  
  let line = `  ${msg.code}${location}: ${msg.message}`;
  if (msg.suggestion) {
    line += `\n    💡 ${msg.suggestion}`;
  }
  return line;
}
