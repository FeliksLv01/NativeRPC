/**
 * NativeRPC Code Generator - TypeScript Parser
 * 
 * Parses TypeScript interface definitions and extracts service modules.
 */

import * as ts from 'typescript';
import * as path from 'path';
import { glob } from 'glob';
import {
  ServiceModule,
  ServiceMethod,
  ServiceEvent,
  MethodParameter,
  MethodKind,
  ValueType,
  ValueTypeKind,
  PrimitiveTypeValue,
  CustomType,
  EnumType,
  TypeField,
} from '../types';

/**
 * Parser options
 */
export interface ParserOptions {
  /** Drop 'I' prefix from interface names */
  dropInterfaceIPrefix?: boolean;
  
  /** Predefined types to skip parsing */
  predefinedTypes?: string[];
  
  /** Path to tsconfig.json */
  tsconfigPath?: string;
}

/**
 * TypeScript Parser for NativeRPC service definitions
 */
export class ServiceParser {
  private program: ts.Program;
  private checker: ts.TypeChecker;
  private options: ParserOptions;
  private predefinedTypes: Set<string>;
  
  /** Collected custom types during parsing */
  private customTypes: Map<string, CustomType> = new Map();
  
  /** Collected enums during parsing */
  private enums: Map<string, EnumType> = new Map();
  
  /** Counter for generating unique inline type names */
  private inlineTypeCounter: number = 0;
  
  /** Current context for naming inline types (e.g., event name) */
  private currentContext: string = '';
  
  constructor(sources: string[], options: ParserOptions = {}) {
    this.options = options;
    this.predefinedTypes = new Set(options.predefinedTypes || []);
    
    // Resolve glob patterns
    const filePaths = sources.flatMap(pattern => glob.sync(pattern));
    
    // Create TypeScript program
    const compilerOptions: ts.CompilerOptions = {
      target: ts.ScriptTarget.ESNext,
      module: ts.ModuleKind.ESNext,
      strict: true,
    };
    
    if (options.tsconfigPath) {
      const configPath = path.resolve(options.tsconfigPath);
      const { config } = ts.readConfigFile(configPath, ts.sys.readFile);
      const parsed = ts.parseJsonConfigFileContent(
        config,
        ts.sys,
        path.dirname(configPath)
      );
      Object.assign(compilerOptions, parsed.options);
    }
    
    this.program = ts.createProgram(filePaths, compilerOptions);
    this.checker = this.program.getTypeChecker();
  }
  
  /**
   * Parse all source files and extract service modules
   */
  parse(): ServiceModule[] {
    const modules: ServiceModule[] = [];
    
    // First pass: collect all enums first
    for (const sourceFile of this.program.getSourceFiles()) {
      if (sourceFile.isDeclarationFile) continue;
      if (sourceFile.fileName.includes('node_modules')) continue;
      
      ts.forEachChild(sourceFile, node => {
        if (ts.isEnumDeclaration(node)) {
          this.parseEnum(node);
        }
      });
    }
    
    // Second pass: collect custom types (now enums are known)
    for (const sourceFile of this.program.getSourceFiles()) {
      if (sourceFile.isDeclarationFile) continue;
      if (sourceFile.fileName.includes('node_modules')) continue;
      
      ts.forEachChild(sourceFile, node => {
        if (ts.isInterfaceDeclaration(node)) {
          // Check if it's NOT a service interface (regular custom type)
          const symbol = this.checker.getSymbolAtLocation(node.name);
          if (symbol) {
            const jsDocTags = this.getJSDocTags(symbol);
            if (!jsDocTags.has('service') && !jsDocTags.has('shouldExport')) {
              this.parseInterfaceAsCustomType(node);
            }
          }
        } else if (ts.isTypeAliasDeclaration(node)) {
          this.parseTypeAlias(node);
        }
      });
    }
    
    // Third pass: parse service interfaces
    for (const sourceFile of this.program.getSourceFiles()) {
      if (sourceFile.isDeclarationFile) continue;
      if (sourceFile.fileName.includes('node_modules')) continue;
      
      ts.forEachChild(sourceFile, node => {
        const module = this.parseNode(node);
        if (module) {
          modules.push(module);
        }
      });
    }
    
    return modules;
  }
  
  private parseNode(node: ts.Node): ServiceModule | null {
    // Only process interface declarations (other types already processed in first pass)
    if (!ts.isInterfaceDeclaration(node)) {
      return null;
    }
    
    const symbol = this.checker.getSymbolAtLocation(node.name);
    if (!symbol) return null;
    
    // Check if this interface should be exported as a service
    const jsDocTags = this.getJSDocTags(symbol);
    if (!jsDocTags.has('service') && !jsDocTags.has('shouldExport')) {
      // Not a service interface, but might be a custom type
      this.parseInterfaceAsCustomType(node);
      return null;
    }
    
    // Get service name from JSDoc or interface name
    let serviceName = jsDocTags.get('serviceName') || node.name.text;
    if (this.options.dropInterfaceIPrefix && serviceName.startsWith('I')) {
      serviceName = serviceName.slice(1);
    }
    // Convert to camelCase for service name
    serviceName = serviceName.charAt(0).toLowerCase() + serviceName.slice(1);
    
    // Parse methods and events
    const methods: ServiceMethod[] = [];
    const events: ServiceEvent[] = [];
    
    for (const member of node.members) {
      if (ts.isMethodSignature(member)) {
        const result = this.parseMethod(member);
        if (result.kind === 'event') {
          events.push(result.event!);
        } else {
          methods.push(result.method!);
        }
      }
    }
    
    // Get documentation
    const documentation = this.getDocumentation(symbol);
    
    return {
      name: this.options.dropInterfaceIPrefix && node.name.text.startsWith('I')
        ? node.name.text.slice(1)
        : node.name.text,
      documentation,
      methods,
      events,
      customTypes: Array.from(this.customTypes.values()),
      enums: Array.from(this.enums.values()),
      customTags: Object.fromEntries(jsDocTags),
    };
  }
  
  private parseMethod(node: ts.MethodSignature): {
    kind: 'method' | 'event';
    method?: ServiceMethod;
    event?: ServiceEvent;
  } {
    const name = node.name.getText();
    const symbol = this.checker.getSymbolAtLocation(node.name);
    const documentation = symbol ? this.getDocumentation(symbol) : '';
    
    // Get return type
    const returnTypeNode = node.type;
    if (!returnTypeNode) {
      return {
        kind: 'method',
        method: {
          name,
          kind: MethodKind.Sync,
          parameters: this.parseParameters(node.parameters),
          returnType: { kind: ValueTypeKind.Void },
          documentation,
          throws: false,
        },
      };
    }
    
    const returnTypeText = returnTypeNode.getText();
    
    // Check if this is an Event<T>
    if (returnTypeText.startsWith('Event<')) {
      // Set context for better inline type naming
      const eventName = name.startsWith('on') ? name.slice(2) : name;
      this.currentContext = eventName.charAt(0).toUpperCase() + eventName.slice(1);
      const payloadType = this.extractGenericType(returnTypeNode, 'Event');
      this.currentContext = '';
      return {
        kind: 'event',
        event: {
          name: name.startsWith('on') ? name.slice(2).charAt(0).toLowerCase() + name.slice(3) : name,
          payloadType,
          documentation,
        },
      };
    }
    
    // Check if this is a Promise<T>
    if (returnTypeText.startsWith('Promise<')) {
      const resultType = this.extractGenericType(returnTypeNode, 'Promise');
      return {
        kind: 'method',
        method: {
          name,
          kind: MethodKind.Async,
          parameters: this.parseParameters(node.parameters),
          returnType: resultType,
          documentation,
          throws: true, // Async methods can throw
        },
      };
    }
    
    // Synchronous method
    const returnType = this.parseType(returnTypeNode);
    return {
      kind: 'method',
      method: {
        name,
        kind: MethodKind.Sync,
        parameters: this.parseParameters(node.parameters),
        returnType,
        documentation,
        throws: false,
      },
    };
  }
  
  private parseParameters(params: ts.NodeArray<ts.ParameterDeclaration>): MethodParameter[] {
    const result: MethodParameter[] = [];
    
    for (const param of params) {
      // Check if parameter is object destructuring (e.g., { value, delay })
      // or a single object type (e.g., args: { value: number })
      if (ts.isObjectBindingPattern(param.name)) {
        // Destructured object parameter
        for (const element of param.name.elements) {
          if (ts.isBindingElement(element) && ts.isIdentifier(element.name)) {
            const paramName = element.name.text;
            const paramType = this.getBindingElementType(element, param);
            result.push({
              name: paramName,
              type: paramType,
              optional: element.initializer !== undefined || param.questionToken !== undefined,
              documentation: '',
            });
          }
        }
      } else if (ts.isIdentifier(param.name) && param.type) {
        // Single object parameter like args: { value: number }
        if (ts.isTypeLiteralNode(param.type)) {
          for (const member of param.type.members) {
            if (ts.isPropertySignature(member) && member.name && member.type) {
              const memberName = member.name.getText();
              const memberType = this.parseType(member.type);
              const memberSymbol = this.checker.getSymbolAtLocation(member.name);
              result.push({
                name: memberName,
                type: memberType,
                optional: member.questionToken !== undefined,
                documentation: memberSymbol ? this.getDocumentation(memberSymbol) : '',
              });
            }
          }
        }
      }
    }
    
    return result;
  }
  
  private getBindingElementType(element: ts.BindingElement, param: ts.ParameterDeclaration): ValueType {
    // Try to get the type from the parameter's type annotation
    if (param.type && ts.isTypeLiteralNode(param.type)) {
      for (const member of param.type.members) {
        if (ts.isPropertySignature(member) && member.name && member.type) {
          if (member.name.getText() === element.name.getText()) {
            return this.parseType(member.type);
          }
        }
      }
    }
    
    // Fallback to any
    return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Any };
  }
  
  private parseType(typeNode: ts.TypeNode): ValueType {
    const typeText = typeNode.getText();
    
    // Void
    if (typeText === 'void') {
      return { kind: ValueTypeKind.Void };
    }
    
    // Primitives
    if (typeText === 'string') {
      return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.String };
    }
    if (typeText === 'number') {
      return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Number };
    }
    if (typeText === 'boolean') {
      return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Boolean };
    }
    if (typeText === 'any' || typeText === 'unknown') {
      return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Any };
    }
    
    // Array types
    if (ts.isArrayTypeNode(typeNode)) {
      return {
        kind: ValueTypeKind.Array,
        elementType: this.parseType(typeNode.elementType),
      };
    }
    
    // Generic Array<T>
    if (ts.isTypeReferenceNode(typeNode) && typeNode.typeName.getText() === 'Array') {
      const typeArg = typeNode.typeArguments?.[0];
      return {
        kind: ValueTypeKind.Array,
        elementType: typeArg ? this.parseType(typeArg) : { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Any },
      };
    }
    
    // Optional type (T | null or T | undefined)
    if (ts.isUnionTypeNode(typeNode)) {
      const types = typeNode.types.filter(t => 
        t.getText() !== 'null' && t.getText() !== 'undefined'
      );
      const hasNull = typeNode.types.some(t => 
        t.getText() === 'null' || t.getText() === 'undefined'
      );
      
      if (hasNull && types.length === 1) {
        return {
          kind: ValueTypeKind.Optional,
          wrappedType: this.parseType(types[0]),
        };
      }
      
      // Union of multiple types
      return {
        kind: ValueTypeKind.Union,
        name: 'Union',
        members: types.map(t => this.parseType(t)),
      };
    }
    
    // Dictionary type { [key: string]: T }
    if (ts.isTypeLiteralNode(typeNode)) {
      const indexSignature = typeNode.members.find(ts.isIndexSignatureDeclaration);
      if (indexSignature && indexSignature.type) {
        return {
          kind: ValueTypeKind.Dictionary,
          keyType: { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.String },
          valueType: this.parseType(indexSignature.type),
        };
      }
      
      // Inline object type - treat as custom type
      const fields: TypeField[] = [];
      for (const member of typeNode.members) {
        if (ts.isPropertySignature(member) && member.name && member.type) {
          fields.push({
            name: member.name.getText(),
            type: this.parseType(member.type),
            optional: member.questionToken !== undefined,
            documentation: '',
          });
        }
      }
      
      // Generate a name for inline types
      // Use context (e.g., event name) for better naming
      let inlineName: string;
      if (this.currentContext) {
        inlineName = `${this.currentContext}Payload`;
        // If already exists with same context, add a counter
        if (this.customTypes.has(inlineName)) {
          this.inlineTypeCounter++;
          inlineName = `${this.currentContext}Payload${this.inlineTypeCounter}`;
        }
      } else {
        this.inlineTypeCounter++;
        inlineName = `InlineType${this.inlineTypeCounter}`;
      }
      const customType: CustomType = {
        kind: ValueTypeKind.Custom,
        name: inlineName,
        fields,
        documentation: '',
      };
      this.customTypes.set(inlineName, customType);
      return customType;
    }
    
    // Type reference (custom type or enum)
    if (ts.isTypeReferenceNode(typeNode)) {
      const typeName = typeNode.typeName.getText();
      
      // Check if it's a predefined type
      if (this.predefinedTypes.has(typeName)) {
        return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Any };
      }
      
      // Check if it's a known enum
      if (this.enums.has(typeName)) {
        const enumDef = this.enums.get(typeName)!;
        return {
          kind: ValueTypeKind.Enum,
          name: typeName,
          members: enumDef.members,
          documentation: enumDef.documentation,
        };
      }
      
      // Return as custom type reference
      return {
        kind: ValueTypeKind.Custom,
        name: typeName,
        fields: [], // Will be filled in later
        documentation: '',
      };
    }
    
    // Fallback
    return { kind: ValueTypeKind.Primitive, value: PrimitiveTypeValue.Any };
  }
  
  private extractGenericType(typeNode: ts.TypeNode, wrapperName: string): ValueType | null {
    if (ts.isTypeReferenceNode(typeNode)) {
      if (typeNode.typeName.getText() === wrapperName && typeNode.typeArguments?.length) {
        return this.parseType(typeNode.typeArguments[0]);
      }
    }
    return null;
  }
  
  private parseInterfaceAsCustomType(node: ts.InterfaceDeclaration): void {
    const name = node.name.text;
    if (this.customTypes.has(name)) return;
    
    const fields: TypeField[] = [];
    for (const member of node.members) {
      if (ts.isPropertySignature(member) && member.name && member.type) {
        const memberSymbol = this.checker.getSymbolAtLocation(member.name);
        fields.push({
          name: member.name.getText(),
          type: this.parseType(member.type),
          optional: member.questionToken !== undefined,
          documentation: memberSymbol ? this.getDocumentation(memberSymbol) : '',
        });
      }
    }
    
    const symbol = this.checker.getSymbolAtLocation(node.name);
    const customType: CustomType = {
      kind: ValueTypeKind.Custom,
      name,
      fields,
      documentation: symbol ? this.getDocumentation(symbol) : '',
    };
    this.customTypes.set(name, customType);
  }
  
  private parseEnum(node: ts.EnumDeclaration): void {
    const name = node.name.text;
    if (this.enums.has(name)) return;
    
    const members: EnumType['members'] = [];
    for (const member of node.members) {
      if (member.name) {
        const memberName = member.name.getText();
        let value: string | number = memberName;
        
        if (member.initializer) {
          if (ts.isStringLiteral(member.initializer)) {
            value = member.initializer.text;
          } else if (ts.isNumericLiteral(member.initializer)) {
            value = parseInt(member.initializer.text, 10);
          }
        }
        
        const memberSymbol = this.checker.getSymbolAtLocation(member.name);
        members.push({
          name: memberName,
          value,
          documentation: memberSymbol ? this.getDocumentation(memberSymbol) : '',
        });
      }
    }
    
    const symbol = this.checker.getSymbolAtLocation(node.name);
    const enumType: EnumType = {
      kind: ValueTypeKind.Enum,
      name,
      members,
      documentation: symbol ? this.getDocumentation(symbol) : '',
    };
    this.enums.set(name, enumType);
  }
  
  private parseTypeAlias(node: ts.TypeAliasDeclaration): void {
    // Handle type aliases like `type Event<T> = { __eventPayload: T }`
    // We skip these as they're just markers
    const name = node.name.text;
    if (name === 'Event') return;
    
    // For other type aliases, treat them as custom types if they're object types
    if (ts.isTypeLiteralNode(node.type)) {
      const fields: TypeField[] = [];
      for (const member of node.type.members) {
        if (ts.isPropertySignature(member) && member.name && member.type) {
          fields.push({
            name: member.name.getText(),
            type: this.parseType(member.type),
            optional: member.questionToken !== undefined,
            documentation: '',
          });
        }
      }
      
      const symbol = this.checker.getSymbolAtLocation(node.name);
      const customType: CustomType = {
        kind: ValueTypeKind.Custom,
        name,
        fields,
        documentation: symbol ? this.getDocumentation(symbol) : '',
      };
      this.customTypes.set(name, customType);
    }
  }
  
  private getJSDocTags(symbol: ts.Symbol): Map<string, string> {
    const tags = new Map<string, string>();
    const jsDocTags = symbol.getJsDocTags();
    
    for (const tag of jsDocTags) {
      const value = tag.text?.map(t => t.text).join('') || 'true';
      tags.set(tag.name, value);
    }
    
    return tags;
  }
  
  private getDocumentation(symbol: ts.Symbol): string {
    const docs = symbol.getDocumentationComment(this.checker);
    return docs.map(d => d.text).join('\n');
  }
  
  /**
   * Get all collected custom types
   */
  getCustomTypes(): CustomType[] {
    return Array.from(this.customTypes.values());
  }
  
  /**
   * Get all collected enums
   */
  getEnums(): EnumType[] {
    return Array.from(this.enums.values());
  }
}
