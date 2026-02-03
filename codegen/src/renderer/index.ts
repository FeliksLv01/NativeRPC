/**
 * NativeRPC Code Generator - Renderer
 * 
 * Renders service modules to language-specific code using Mustache templates.
 */

import * as fs from 'fs';
import * as path from 'path';
import * as Mustache from 'mustache';
import {
  ServiceModule,
  ServiceMethod,
  ServiceEvent,
  MethodKind,
  CustomType,
  EnumType,
  ValueType,
  TypeField,
  isVoidType,
  isPrimitiveType,
  isArrayType,
  isCustomType,
  isOptionalType,
  isEnumType,
  PrimitiveTypeValue,
} from '../types';
import {
  TypeTransformer,
  SwiftTypeTransformer,
  KotlinTypeTransformer,
  DartTypeTransformer,
  TypeScriptTypeTransformer,
} from './type-transformer';
import { SwiftServiceMerger, KotlinServiceMerger, ExistingServiceInfo } from '../merger';

// ============================================================================
// View Models (Mustache-friendly data structures)
// ============================================================================

interface ServiceView {
  serviceName: string;
  className: string;
  baseClass: string;
  documentation: string;
  documentationLines: { line: string }[];
  hasDocumentation: boolean;
  syncMethods: MethodView[];
  asyncMethods: MethodView[];
  voidMethods: MethodView[];
  allMethods: MethodView[];
  events: EventView[];
}

interface MethodView {
  methodName: string;
  methodNamePascal: string;
  documentation: string;
  documentationLines: { line: string }[];
  hasDocumentation: boolean;
  hasParams: boolean;
  parameterCount: number;
  parameters: ParameterView[];
  returnType: string;
  existingImplementation?: string;
}

interface ParameterView {
  name: string;
  type: string;
  optional: boolean;
  last: boolean;
  first: boolean;
}

interface EventView {
  eventName: string;
  eventNamePascal: string;
  documentation: string;
  documentationLines: { line: string }[];
  hasDocumentation: boolean;
  hasPayload: boolean;
  payloadType: string;
}

interface CustomTypeView {
  name: string;
  documentation: string;
  hasDocumentation: boolean;
  fields: FieldView[];
}

interface FieldView {
  name: string;
  type: string;
  optional: boolean;
  documentation: string;
  last: boolean;
  first: boolean;
  // JSON conversion expressions
  fromJson: string;
  toJson: string;
}

interface EnumView {
  name: string;
  documentation: string;
  hasDocumentation: boolean;
  members: EnumMemberView[];
  // Language-specific value type
  valueType: string;      // Dart: String
  rawType: string;        // Swift/Kotlin: String or Int
}

interface EnumMemberView {
  name: string;
  value: string | number;
  documentation: string;
  hasDocumentation: boolean;
  last: boolean;
  isString: boolean;
  // Language-specific member names
  dartName: string;       // camelCase
  swiftName: string;      // camelCase
  kotlinName: string;     // UPPER_SNAKE_CASE
  tsName: string;         // PascalCase (original)
}

interface TemplateView {
  sourceFile: string;
  timestamp: string;
  imports: string[];
  packageName?: string;
  className?: string;  // Top-level className for use outside {{#services}} block
  customTypes: CustomTypeView[];
  enums: EnumView[];
  services: ServiceView[];
}

// ============================================================================
// JSON Converter Generators
// ============================================================================

abstract class JsonConverterGenerator {
  abstract fromJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string;
  abstract toJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string;
}

class DartJsonConverter extends JsonConverterGenerator {
  fromJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return `json['${fieldName}'] as String`;
        case PrimitiveTypeValue.Number:
          return `(json['${fieldName}'] as num).toDouble()`;
        case PrimitiveTypeValue.Int:
          return `json['${fieldName}'] as int`;
        case PrimitiveTypeValue.Boolean:
          return `json['${fieldName}'] as bool`;
        default:
          return `json['${fieldName}']`;
      }
    }
    if (isOptionalType(type)) {
      const inner = this.fromJson(fieldName, type.wrappedType, transformer);
      return `json['${fieldName}'] != null ? ${inner} : null`;
    }
    if (isArrayType(type)) {
      const elemType = transformer.convert(type.elementType);
      if (isPrimitiveType(type.elementType)) {
        return `(json['${fieldName}'] as List).cast<${elemType}>()`;
      }
      return `(json['${fieldName}'] as List).map((e) => ${elemType}.fromJson(e as Map<String, dynamic>)).toList()`;
    }
    if (isCustomType(type)) {
      return `${type.name}.fromJson(json['${fieldName}'] as Map<String, dynamic>)`;
    }
    if (isEnumType(type)) {
      return `${type.name}.fromValue(json['${fieldName}'] as String)!`;
    }
    return `json['${fieldName}']`;
  }

  toJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    if (isPrimitiveType(type)) {
      return fieldName;
    }
    if (isOptionalType(type)) {
      return `${fieldName}`;
    }
    if (isArrayType(type)) {
      if (isPrimitiveType(type.elementType)) {
        return fieldName;
      }
      return `${fieldName}.map((e) => e.toJson()).toList()`;
    }
    if (isCustomType(type)) {
      return `${fieldName}.toJson()`;
    }
    if (isEnumType(type)) {
      return `${fieldName}.value`;
    }
    return fieldName;
  }
}

class SwiftJsonConverter extends JsonConverterGenerator {
  fromJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    // Swift uses Codable, so no manual conversion needed
    return fieldName;
  }

  toJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    return fieldName;
  }
}

class KotlinJsonConverter extends JsonConverterGenerator {
  fromJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return `json["${fieldName}"] as String`;
        case PrimitiveTypeValue.Number:
          return `(json["${fieldName}"] as Number).toDouble()`;
        case PrimitiveTypeValue.Int:
          return `(json["${fieldName}"] as Number).toInt()`;
        case PrimitiveTypeValue.Boolean:
          return `json["${fieldName}"] as Boolean`;
        default:
          return `json["${fieldName}"]`;
      }
    }
    if (isOptionalType(type)) {
      const inner = this.fromJson(fieldName, type.wrappedType, transformer);
      return `json["${fieldName}"]?.let { ${inner.replace(`json["${fieldName}"]`, 'it')} }`;
    }
    if (isArrayType(type)) {
      const elemType = transformer.convert(type.elementType);
      if (isPrimitiveType(type.elementType)) {
        return `(json["${fieldName}"] as List<*>).filterIsInstance<${elemType}>()`;
      }
      return `(json["${fieldName}"] as List<*>).map { ${elemType}.fromJson(it as Map<String, Any?>) }`;
    }
    if (isCustomType(type)) {
      return `${type.name}.fromJson(json["${fieldName}"] as Map<String, Any?>)`;
    }
    if (isEnumType(type)) {
      return `${type.name}.valueOf(json["${fieldName}"] as String)`;
    }
    return `json["${fieldName}"]`;
  }

  toJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    if (isPrimitiveType(type)) {
      return fieldName;
    }
    if (isOptionalType(type)) {
      return fieldName;
    }
    if (isArrayType(type)) {
      if (isPrimitiveType(type.elementType)) {
        return fieldName;
      }
      return `${fieldName}.map { it.toJson() }`;
    }
    if (isCustomType(type)) {
      return `${fieldName}.toJson()`;
    }
    if (isEnumType(type)) {
      return `${fieldName}.name`;
    }
    return fieldName;
  }
}

class TypeScriptJsonConverter extends JsonConverterGenerator {
  fromJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    // TypeScript doesn't need runtime conversion for JSON
    return `json.${fieldName}`;
  }

  toJson(fieldName: string, type: ValueType, transformer: TypeTransformer): string {
    return `this.${fieldName}`;
  }
}

// ============================================================================
// Renderer Classes
// ============================================================================

/**
 * Base renderer class
 */
export abstract class ServiceRenderer {
  protected templateDir: string;
  protected transformer: TypeTransformer;
  protected jsonConverter: JsonConverterGenerator;
  protected serviceSuffix: string;
  
  constructor(
    templateDir: string, 
    transformer: TypeTransformer, 
    jsonConverter: JsonConverterGenerator,
    serviceSuffix: string = 'RPCService'
  ) {
    this.templateDir = templateDir;
    this.transformer = transformer;
    this.jsonConverter = jsonConverter;
    this.serviceSuffix = serviceSuffix;
  }
  
  /**
   * Render a service module to code
   */
  render(
    module: ServiceModule,
    templateName: string,
    existingImplementations?: Map<string, string>
  ): string {
    const templatePath = path.join(this.templateDir, templateName);
    const template = fs.readFileSync(templatePath, 'utf-8');
    
    // Load partials
    const partials = this.loadPartials();
    
    // Build view
    const view = this.buildView(module, existingImplementations);
    
    return Mustache.render(template, view, partials);
  }
  
  protected abstract buildView(
    module: ServiceModule,
    existingImplementations?: Map<string, string>
  ): TemplateView;
  
  protected abstract loadPartials(): Record<string, string>;
  
  /**
   * Get the service class name with configurable suffix.
   * Removes any existing "Service" suffix and adds the configured suffix.
   * e.g., CounterService + suffix "RPCService" => CounterRPCService
   */
  protected getServiceClassName(moduleName: string): string {
    const baseName = moduleName.replace(/Service$/, '');
    return `${baseName}${this.serviceSuffix}`;
  }
  
  /**
   * Format documentation for the target language.
   * Override in subclasses to customize formatting.
   */
  protected formatDocumentation(doc: string, prefix: string = ''): string {
    if (!doc || doc.trim().length === 0) {
      return '';
    }
    // Default: just return as-is
    return doc;
  }
  
  /**
   * Split documentation into lines for Mustache iteration.
   */
  protected splitDocumentation(doc: string): { line: string }[] {
    if (!doc || doc.trim().length === 0) {
      return [];
    }
    return doc.split('\n').map(line => ({ line: line.trim() }));
  }
  
  protected toPascalCase(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }
  
  protected buildMethodView(
    method: ServiceMethod,
    existingImplementation?: string
  ): MethodView {
    const params = method.parameters.map((p, i) => ({
      name: p.name,
      type: this.transformer.convert(p.type),
      optional: p.optional,
      last: i === method.parameters.length - 1,
      first: i === 0,
    }));
    
    const docLines = this.splitDocumentation(method.documentation);
    
    return {
      methodName: method.name,
      methodNamePascal: this.toPascalCase(method.name),
      documentation: method.documentation,
      documentationLines: docLines,
      hasDocumentation: method.documentation.length > 0,
      hasParams: params.length > 0,
      parameterCount: params.length,
      parameters: params,
      returnType: method.returnType ? this.transformer.convert(method.returnType) : 'Void',
      existingImplementation,
    };
  }
  
  protected buildEventView(event: ServiceEvent): EventView {
    const docLines = this.splitDocumentation(event.documentation);
    
    return {
      eventName: event.name,
      eventNamePascal: this.toPascalCase(event.name),
      documentation: event.documentation,
      documentationLines: docLines,
      hasDocumentation: event.documentation.length > 0,
      hasPayload: event.payloadType !== null && !isVoidType(event.payloadType),
      payloadType: event.payloadType ? this.transformer.convert(event.payloadType) : 'Void',
    };
  }
  
  protected buildCustomTypeView(customType: CustomType, originalFields: TypeField[]): CustomTypeView {
    return {
      name: customType.name,
      documentation: customType.documentation,
      hasDocumentation: customType.documentation.length > 0,
      fields: customType.fields.map((f, i) => {
        const originalField = originalFields.find(of => of.name === f.name) || f;
        return {
          name: f.name,
          type: this.transformer.convert(f.type),
          optional: f.optional,
          documentation: f.documentation,
          last: i === customType.fields.length - 1,
          first: i === 0,
          fromJson: this.jsonConverter.fromJson(f.name, originalField.type, this.transformer),
          toJson: this.jsonConverter.toJson(f.name, originalField.type, this.transformer),
        };
      }),
    };
  }
  
  protected buildEnumView(enumType: EnumType): EnumView {
    // Determine if values are strings or numbers based on first member
    const isStringEnum = enumType.members.length > 0 && typeof enumType.members[0].value === 'string';
    
    return {
      name: enumType.name,
      documentation: enumType.documentation,
      hasDocumentation: enumType.documentation.length > 0,
      valueType: isStringEnum ? 'String' : 'int',  // Dart
      rawType: isStringEnum ? 'String' : 'Int',    // Swift/Kotlin
      members: enumType.members.map((m, i) => ({
        name: m.name,
        value: m.value,
        documentation: m.documentation,
        hasDocumentation: m.documentation.length > 0,
        last: i === enumType.members.length - 1,
        isString: typeof m.value === 'string',
        // Language-specific naming
        dartName: this.toCamelCase(m.name),
        swiftName: this.toCamelCase(m.name),
        kotlinName: this.toUpperSnakeCase(m.name),
        tsName: m.name, // Keep original PascalCase
      })),
    };
  }
  
  protected toCamelCase(str: string): string {
    return str.charAt(0).toLowerCase() + str.slice(1);
  }
  
  protected toUpperSnakeCase(str: string): string {
    return str
      .replace(/([A-Z])/g, '_$1')
      .toUpperCase()
      .replace(/^_/, '');
  }
  
  protected loadPartial(dir: string, name: string): string {
    const filePath = path.join(dir, name);
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf-8');
    }
    return '';
  }
}

// ============================================================================
// Swift Renderer
// ============================================================================

export class SwiftRenderer extends ServiceRenderer {
  private merger: SwiftServiceMerger;
  
  constructor(templateDir: string, serviceSuffix: string = 'RPCService') {
    super(templateDir, new SwiftTypeTransformer(), new SwiftJsonConverter(), serviceSuffix);
    this.merger = new SwiftServiceMerger();
  }
  
  /**
   * Render with incremental update support
   */
  renderWithMerge(
    module: ServiceModule,
    existingFilePath?: string
  ): string {
    let existingImplementations: Map<string, string> | undefined;
    
    if (existingFilePath && fs.existsSync(existingFilePath)) {
      const existingInfo = this.merger.parseExisting(existingFilePath);
      if (existingInfo) {
        existingImplementations = new Map();
        for (const [name, _method] of existingInfo.methods) {
          const impl = this.merger.getExistingImplementation(existingInfo, name);
          if (impl) {
            existingImplementations.set(name, impl);
          }
        }
      }
    }
    
    return this.render(module, 'service.mustache', existingImplementations);
  }
  
  /**
   * Render Types extension file with Params structs
   */
  renderTypesExtension(module: ServiceModule): string {
    const templatePath = path.join(this.templateDir, 'swift-params.mustache');
    const template = fs.readFileSync(templatePath, 'utf-8');
    
    // Build view with allMethods for types
    const view = this.buildView(module);
    
    return Mustache.render(template, view);
  }
  
  protected buildView(
    module: ServiceModule,
    existingImplementations?: Map<string, string>
  ): TemplateView {
    const syncMethods: MethodView[] = [];
    const asyncMethods: MethodView[] = [];
    const voidMethods: MethodView[] = [];
    const allMethods: MethodView[] = [];
    
    for (const method of module.methods) {
      const existing = existingImplementations?.get(method.name);
      const view = this.buildMethodView(method, existing);
      
      // Add to allMethods for params generation
      allMethods.push(view);
      
      if (method.returnType === null || isVoidType(method.returnType)) {
        voidMethods.push(view);
      } else if (method.kind === MethodKind.Async) {
        asyncMethods.push(view);
      } else {
        syncMethods.push(view);
      }
    }
    
    const events = module.events.map(e => this.buildEventView(e));
    const className = this.getServiceClassName(module.name);
    
    return {
      sourceFile: 'services.ts',
      timestamp: new Date().toISOString(),
      imports: ['NativeRPCKit'],
      className,  // Top-level className for header comments
      customTypes: module.customTypes.map(t => this.buildCustomTypeView(t, t.fields)),
      enums: module.enums.map(e => this.buildEnumView(e)),
      services: [{
        serviceName: module.name.charAt(0).toLowerCase() + module.name.slice(1).replace(/Service$/, ''),
        className,
        baseClass: 'NativeRPCService',
        documentation: module.documentation,
        documentationLines: this.splitDocumentation(module.documentation),
        hasDocumentation: module.documentation.length > 0,
        syncMethods,
        asyncMethods,
        voidMethods,
        allMethods,
        events,
      }],
    };
  }
  
  protected loadPartials(): Record<string, string> {
    return {
      'swift-type': this.loadPartial(this.templateDir, 'swift-type.mustache'),
      'swift-enum': this.loadPartial(this.templateDir, 'swift-enum.mustache'),
    };
  }
}

// ============================================================================
// Kotlin Renderer
// ============================================================================

export class KotlinRenderer extends ServiceRenderer {
  private merger: KotlinServiceMerger;
  private packageName: string;
  
  constructor(templateDir: string, packageName: string = 'com.itoken.team', serviceSuffix: string = 'RPCService') {
    super(templateDir, new KotlinTypeTransformer(), new KotlinJsonConverter(), serviceSuffix);
    this.merger = new KotlinServiceMerger();
    this.packageName = packageName;
  }
  
  /**
   * Render with incremental update support
   */
  renderWithMerge(
    module: ServiceModule,
    existingFilePath?: string
  ): string {
    let existingImplementations: Map<string, string> | undefined;
    
    if (existingFilePath && fs.existsSync(existingFilePath)) {
      const existingInfo = this.merger.parseExisting(existingFilePath);
      if (existingInfo) {
        existingImplementations = new Map();
        for (const [name, _method] of existingInfo.methods) {
          const impl = this.merger.getExistingImplementation(existingInfo, name);
          if (impl) {
            existingImplementations.set(name, impl);
          }
        }
      }
    }
    
    return this.render(module, 'service.mustache', existingImplementations);
  }
  
  protected buildView(
    module: ServiceModule,
    existingImplementations?: Map<string, string>
  ): TemplateView {
    const syncMethods: MethodView[] = [];
    const asyncMethods: MethodView[] = [];
    const voidMethods: MethodView[] = [];
    const allMethods: MethodView[] = [];
    
    for (const method of module.methods) {
      const existing = existingImplementations?.get(method.name);
      const view = this.buildKotlinMethodView(method, existing);
      
      allMethods.push(view);
      
      if (method.returnType === null || isVoidType(method.returnType)) {
        voidMethods.push(view);
      } else if (method.kind === MethodKind.Async) {
        asyncMethods.push(view);
      } else {
        syncMethods.push(view);
      }
    }
    
    const events = module.events.map(e => this.buildEventView(e));
    const className = this.getServiceClassName(module.name);
    
    return {
      sourceFile: 'services.ts',
      timestamp: new Date().toISOString(),
      imports: [
        'com.itoken.team.nativerpc.core.NativeRPCService',
        'com.itoken.team.nativerpc.core.NativeRPCContext',
        'com.itoken.team.nativerpc.core.NativeRPCServiceFactory',
        'com.itoken.team.nativerpc.dsl.serviceDefinition',
      ],
      packageName: this.packageName,
      className,
      customTypes: module.customTypes.map(t => this.buildCustomTypeView(t, t.fields)),
      enums: module.enums.map(e => this.buildEnumView(e)),
      services: [{
        serviceName: module.name.charAt(0).toLowerCase() + module.name.slice(1).replace(/Service$/, ''),
        className,
        baseClass: 'NativeRPCService',
        documentation: module.documentation,
        documentationLines: this.splitDocumentation(module.documentation),
        hasDocumentation: module.documentation.length > 0,
        syncMethods,
        asyncMethods,
        voidMethods,
        allMethods,
        events,
      }],
    };
  }
  
  /**
   * Build Kotlin method view (now uses same pattern as Swift with Params types)
   */
  private buildKotlinMethodView(
    method: ServiceMethod,
    existingImplementation?: string
  ): MethodView {
    // Now that we use Codable-style params, we can just use the base method view
    return this.buildMethodView(method, existingImplementation);
  }
  
  protected loadPartials(): Record<string, string> {
    return {
      'kotlin-type': this.loadPartial(this.templateDir, 'kotlin-type.mustache'),
      'kotlin-enum': this.loadPartial(this.templateDir, 'kotlin-enum.mustache'),
    };
  }
}

// ============================================================================
// Dart Renderer
// ============================================================================

export class DartRenderer extends ServiceRenderer {
  constructor(templateDir: string, serviceSuffix: string = 'RPCService') {
    super(templateDir, new DartTypeTransformer(), new DartJsonConverter(), serviceSuffix);
  }
  
  protected buildView(
    module: ServiceModule,
    _existingImplementations?: Map<string, string>
  ): TemplateView {
    const syncMethods: MethodView[] = [];
    const asyncMethods: MethodView[] = [];
    const voidMethods: MethodView[] = [];
    const allMethods: MethodView[] = [];
    
    // All methods are async in Dart (calling native)
    for (const method of module.methods) {
      const view = this.buildMethodView(method);
      
      allMethods.push(view);
      
      if (method.returnType === null || isVoidType(method.returnType)) {
        voidMethods.push(view);
      } else {
        asyncMethods.push(view);
      }
    }
    
    const events = module.events.map(e => this.buildEventView(e));
    const className = this.getServiceClassName(module.name);
    
    return {
      sourceFile: 'services.ts',
      timestamp: new Date().toISOString(),
      imports: ["import 'package:native_rpc_flutter/native_rpc_flutter.dart';"],
      customTypes: module.customTypes.map(t => this.buildCustomTypeView(t, t.fields)),
      enums: module.enums.map(e => this.buildEnumView(e)),
      services: [{
        serviceName: module.name.charAt(0).toLowerCase() + module.name.slice(1).replace(/Service$/, ''),
        className,
        baseClass: 'NativeRPCService',
        documentation: module.documentation,
        documentationLines: this.splitDocumentation(module.documentation),
        hasDocumentation: module.documentation.length > 0,
        syncMethods,
        asyncMethods,
        voidMethods,
        allMethods,
        events,
      }],
    };
  }
  
  protected loadPartials(): Record<string, string> {
    return {
      'dart-type': this.loadPartial(this.templateDir, 'dart-type.mustache'),
      'dart-enum': this.loadPartial(this.templateDir, 'dart-enum.mustache'),
    };
  }
}

// ============================================================================
// TypeScript Renderer
// ============================================================================

export class TypeScriptRenderer extends ServiceRenderer {
  constructor(templateDir: string, serviceSuffix: string = 'RPCService') {
    super(templateDir, new TypeScriptTypeTransformer(), new TypeScriptJsonConverter(), serviceSuffix);
  }
  
  protected buildView(
    module: ServiceModule,
    _existingImplementations?: Map<string, string>
  ): TemplateView {
    const syncMethods: MethodView[] = [];
    const asyncMethods: MethodView[] = [];
    const voidMethods: MethodView[] = [];
    const allMethods: MethodView[] = [];
    
    // All methods are async in TypeScript client (calling native)
    for (const method of module.methods) {
      const view = this.buildMethodView(method);
      
      allMethods.push(view);
      
      if (method.returnType === null || isVoidType(method.returnType)) {
        voidMethods.push(view);
      } else {
        asyncMethods.push(view);
      }
    }
    
    const events = module.events.map(e => this.buildEventView(e));
    const className = this.getServiceClassName(module.name);
    
    return {
      sourceFile: 'services.ts',
      timestamp: new Date().toISOString(),
      imports: [],
      customTypes: module.customTypes.map(t => this.buildCustomTypeView(t, t.fields)),
      enums: module.enums.map(e => this.buildEnumView(e)),
      services: [{
        serviceName: module.name.charAt(0).toLowerCase() + module.name.slice(1).replace(/Service$/, ''),
        className,
        baseClass: 'NativeRPCService',
        documentation: module.documentation,
        documentationLines: this.splitDocumentation(module.documentation),
        hasDocumentation: module.documentation.length > 0,
        syncMethods,
        asyncMethods,
        voidMethods,
        allMethods,
        events,
      }],
    };
  }
  
  protected loadPartials(): Record<string, string> {
    return {
      'ts-type': this.loadPartial(this.templateDir, 'ts-type.mustache'),
      'ts-enum': this.loadPartial(this.templateDir, 'ts-enum.mustache'),
    };
  }
}

// ============================================================================
// Exports
// ============================================================================

export * from './type-transformer';
