/**
 * NativeRPC Code Generator - Core Types
 * 
 * These types represent the parsed structure of a NativeRPC service definition.
 */

/**
 * Represents a complete service module
 */
export interface ServiceModule {
  /** Service name (e.g., "counter", "user") */
  name: string;
  
  /** Documentation comments for the service */
  documentation: string;
  
  /** All methods in the service */
  methods: ServiceMethod[];
  
  /** All events the service can emit */
  events: ServiceEvent[];
  
  /** Custom types defined in the service */
  customTypes: CustomType[];
  
  /** Enums defined in the service */
  enums: EnumType[];
  
  /** Custom JSDoc tags */
  customTags: Record<string, unknown>;
}

/**
 * Method kind determines how it's called and implemented
 */
export enum MethodKind {
  /** Synchronous method - returns value directly */
  Sync = 'sync',
  
  /** Asynchronous method - returns Promise */
  Async = 'async',
}

/**
 * Represents a method in a service
 */
export interface ServiceMethod {
  /** Method name (e.g., "increment", "getValue") */
  name: string;
  
  /** Method kind (sync or async) */
  kind: MethodKind;
  
  /** Method parameters */
  parameters: MethodParameter[];
  
  /** Return type (null for void) */
  returnType: ValueType | null;
  
  /** Documentation comments */
  documentation: string;
  
  /** Whether the method can throw errors */
  throws: boolean;
}

/**
 * Represents an event that can be emitted by a service
 */
export interface ServiceEvent {
  /** Event name (e.g., "countChanged", "statusUpdated") */
  name: string;
  
  /** Event payload type */
  payloadType: ValueType | null;
  
  /** Documentation comments */
  documentation: string;
}

/**
 * Represents a method parameter
 */
export interface MethodParameter {
  /** Parameter name */
  name: string;
  
  /** Parameter type */
  type: ValueType;
  
  /** Whether the parameter is optional */
  optional: boolean;
  
  /** Default value if any */
  defaultValue?: string;
  
  /** Documentation */
  documentation: string;
}

// ============================================================================
// Value Types
// ============================================================================

export type ValueType = 
  | PrimitiveType 
  | ArrayType 
  | DictionaryType 
  | OptionalType 
  | CustomType
  | EnumType
  | UnionType
  | TupleType
  | VoidType;

export enum ValueTypeKind {
  Primitive = 'primitive',
  Array = 'array',
  Dictionary = 'dictionary',
  Optional = 'optional',
  Custom = 'custom',
  Enum = 'enum',
  Union = 'union',
  Tuple = 'tuple',
  Void = 'void',
}

export enum PrimitiveTypeValue {
  String = 'string',
  Number = 'number',
  Int = 'int',
  Boolean = 'boolean',
  Any = 'any',
}

export interface PrimitiveType {
  kind: ValueTypeKind.Primitive;
  value: PrimitiveTypeValue;
}

export interface ArrayType {
  kind: ValueTypeKind.Array;
  elementType: ValueType;
}

export interface DictionaryType {
  kind: ValueTypeKind.Dictionary;
  keyType: PrimitiveType;
  valueType: ValueType;
}

export interface OptionalType {
  kind: ValueTypeKind.Optional;
  wrappedType: ValueType;
}

export interface CustomType {
  kind: ValueTypeKind.Custom;
  name: string;
  fields: TypeField[];
  documentation: string;
}

export interface TypeField {
  name: string;
  type: ValueType;
  optional: boolean;
  documentation: string;
}

export interface EnumType {
  kind: ValueTypeKind.Enum;
  name: string;
  members: EnumMember[];
  documentation: string;
}

export interface EnumMember {
  name: string;
  value: string | number;
  documentation: string;
}

export interface UnionType {
  kind: ValueTypeKind.Union;
  name: string;
  members: ValueType[];
}

export interface TupleType {
  kind: ValueTypeKind.Tuple;
  members: ValueType[];
}

export interface VoidType {
  kind: ValueTypeKind.Void;
}

// ============================================================================
// Helper Functions
// ============================================================================

export function isPrimitiveType(type: ValueType): type is PrimitiveType {
  return type.kind === ValueTypeKind.Primitive;
}

export function isArrayType(type: ValueType): type is ArrayType {
  return type.kind === ValueTypeKind.Array;
}

export function isDictionaryType(type: ValueType): type is DictionaryType {
  return type.kind === ValueTypeKind.Dictionary;
}

export function isOptionalType(type: ValueType): type is OptionalType {
  return type.kind === ValueTypeKind.Optional;
}

export function isCustomType(type: ValueType): type is CustomType {
  return type.kind === ValueTypeKind.Custom;
}

export function isEnumType(type: ValueType): type is EnumType {
  return type.kind === ValueTypeKind.Enum;
}

export function isUnionType(type: ValueType): type is UnionType {
  return type.kind === ValueTypeKind.Union;
}

export function isTupleType(type: ValueType): type is TupleType {
  return type.kind === ValueTypeKind.Tuple;
}

export function isVoidType(type: ValueType): type is VoidType {
  return type.kind === ValueTypeKind.Void;
}
