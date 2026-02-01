/**
 * NativeRPC Code Generator - Type Transformers
 * 
 * Converts ValueType to language-specific type strings.
 */

import {
  ValueType,
  ValueTypeKind,
  PrimitiveTypeValue,
  isPrimitiveType,
  isArrayType,
  isDictionaryType,
  isOptionalType,
  isCustomType,
  isEnumType,
  isUnionType,
  isTupleType,
  isVoidType,
} from '../types';

/**
 * Interface for type transformers
 */
export interface TypeTransformer {
  /**
   * Convert a ValueType to a language-specific type string
   */
  convert(type: ValueType): string;
  
  /**
   * Get the default value for a type (used in templates)
   */
  defaultValue(type: ValueType): string;
}

// ============================================================================
// Swift Type Transformer
// ============================================================================

export class SwiftTypeTransformer implements TypeTransformer {
  convert(type: ValueType): string {
    if (isVoidType(type)) {
      return 'Void';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return 'String';
        case PrimitiveTypeValue.Number:
          return 'Double';
        case PrimitiveTypeValue.Int:
          return 'Int';
        case PrimitiveTypeValue.Boolean:
          return 'Bool';
        case PrimitiveTypeValue.Any:
          return 'Any';
      }
    }
    
    if (isArrayType(type)) {
      return `[${this.convert(type.elementType)}]`;
    }
    
    if (isDictionaryType(type)) {
      return `[${this.convert(type.keyType)}: ${this.convert(type.valueType)}]`;
    }
    
    if (isOptionalType(type)) {
      return `${this.convert(type.wrappedType)}?`;
    }
    
    if (isCustomType(type)) {
      return type.name;
    }
    
    if (isEnumType(type)) {
      return type.name;
    }
    
    if (isUnionType(type)) {
      // Swift doesn't have union types, use Any or a protocol
      return 'Any';
    }
    
    if (isTupleType(type)) {
      const members = type.members.map(m => this.convert(m)).join(', ');
      return `(${members})`;
    }
    
    return 'Any';
  }
  
  defaultValue(type: ValueType): string {
    if (isVoidType(type)) {
      return '';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return '""';
        case PrimitiveTypeValue.Number:
          return '0.0';
        case PrimitiveTypeValue.Int:
          return '0';
        case PrimitiveTypeValue.Boolean:
          return 'false';
        case PrimitiveTypeValue.Any:
          return 'nil';
      }
    }
    
    if (isArrayType(type)) {
      return '[]';
    }
    
    if (isDictionaryType(type)) {
      return '[:]';
    }
    
    if (isOptionalType(type)) {
      return 'nil';
    }
    
    return 'fatalError("Not implemented")';
  }
}

// ============================================================================
// Kotlin Type Transformer
// ============================================================================

export class KotlinTypeTransformer implements TypeTransformer {
  convert(type: ValueType): string {
    if (isVoidType(type)) {
      return 'Unit';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return 'String';
        case PrimitiveTypeValue.Number:
          return 'Double';
        case PrimitiveTypeValue.Int:
          return 'Int';
        case PrimitiveTypeValue.Boolean:
          return 'Boolean';
        case PrimitiveTypeValue.Any:
          return 'Any';
      }
    }
    
    if (isArrayType(type)) {
      return `List<${this.convert(type.elementType)}>`;
    }
    
    if (isDictionaryType(type)) {
      return `Map<${this.convert(type.keyType)}, ${this.convert(type.valueType)}>`;
    }
    
    if (isOptionalType(type)) {
      return `${this.convert(type.wrappedType)}?`;
    }
    
    if (isCustomType(type)) {
      return type.name;
    }
    
    if (isEnumType(type)) {
      return type.name;
    }
    
    if (isUnionType(type)) {
      return 'Any';
    }
    
    if (isTupleType(type)) {
      // Kotlin uses Pair/Triple or data classes
      if (type.members.length === 2) {
        return `Pair<${this.convert(type.members[0])}, ${this.convert(type.members[1])}>`;
      }
      if (type.members.length === 3) {
        return `Triple<${this.convert(type.members[0])}, ${this.convert(type.members[1])}, ${this.convert(type.members[2])}>`;
      }
      return 'Any';
    }
    
    return 'Any';
  }
  
  defaultValue(type: ValueType): string {
    if (isVoidType(type)) {
      return '';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return '""';
        case PrimitiveTypeValue.Number:
          return '0.0';
        case PrimitiveTypeValue.Int:
          return '0';
        case PrimitiveTypeValue.Boolean:
          return 'false';
        case PrimitiveTypeValue.Any:
          return 'null';
      }
    }
    
    if (isArrayType(type)) {
      return 'emptyList()';
    }
    
    if (isDictionaryType(type)) {
      return 'emptyMap()';
    }
    
    if (isOptionalType(type)) {
      return 'null';
    }
    
    return 'TODO("Not implemented")';
  }
}

// ============================================================================
// Dart Type Transformer
// ============================================================================

export class DartTypeTransformer implements TypeTransformer {
  convert(type: ValueType): string {
    if (isVoidType(type)) {
      return 'void';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return 'String';
        case PrimitiveTypeValue.Number:
          return 'double';
        case PrimitiveTypeValue.Int:
          return 'int';
        case PrimitiveTypeValue.Boolean:
          return 'bool';
        case PrimitiveTypeValue.Any:
          return 'dynamic';
      }
    }
    
    if (isArrayType(type)) {
      return `List<${this.convert(type.elementType)}>`;
    }
    
    if (isDictionaryType(type)) {
      return `Map<${this.convert(type.keyType)}, ${this.convert(type.valueType)}>`;
    }
    
    if (isOptionalType(type)) {
      return `${this.convert(type.wrappedType)}?`;
    }
    
    if (isCustomType(type)) {
      return type.name;
    }
    
    if (isEnumType(type)) {
      return type.name;
    }
    
    if (isUnionType(type)) {
      return 'dynamic';
    }
    
    if (isTupleType(type)) {
      // Dart uses records in Dart 3
      const members = type.members.map(m => this.convert(m)).join(', ');
      return `(${members})`;
    }
    
    return 'dynamic';
  }
  
  defaultValue(type: ValueType): string {
    if (isVoidType(type)) {
      return '';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return "''";
        case PrimitiveTypeValue.Number:
          return '0.0';
        case PrimitiveTypeValue.Int:
          return '0';
        case PrimitiveTypeValue.Boolean:
          return 'false';
        case PrimitiveTypeValue.Any:
          return 'null';
      }
    }
    
    if (isArrayType(type)) {
      return '[]';
    }
    
    if (isDictionaryType(type)) {
      return '{}';
    }
    
    if (isOptionalType(type)) {
      return 'null';
    }
    
    return "throw UnimplementedError()";
  }
}

// ============================================================================
// TypeScript Type Transformer
// ============================================================================

export class TypeScriptTypeTransformer implements TypeTransformer {
  convert(type: ValueType): string {
    if (isVoidType(type)) {
      return 'void';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return 'string';
        case PrimitiveTypeValue.Number:
          return 'number';
        case PrimitiveTypeValue.Int:
          return 'number';
        case PrimitiveTypeValue.Boolean:
          return 'boolean';
        case PrimitiveTypeValue.Any:
          return 'any';
      }
    }
    
    if (isArrayType(type)) {
      return `${this.convert(type.elementType)}[]`;
    }
    
    if (isDictionaryType(type)) {
      return `Record<${this.convert(type.keyType)}, ${this.convert(type.valueType)}>`;
    }
    
    if (isOptionalType(type)) {
      return `${this.convert(type.wrappedType)} | null`;
    }
    
    if (isCustomType(type)) {
      return type.name;
    }
    
    if (isEnumType(type)) {
      return type.name;
    }
    
    if (isUnionType(type)) {
      return type.members.map(m => this.convert(m)).join(' | ');
    }
    
    if (isTupleType(type)) {
      const members = type.members.map(m => this.convert(m)).join(', ');
      return `[${members}]`;
    }
    
    return 'any';
  }
  
  defaultValue(type: ValueType): string {
    if (isVoidType(type)) {
      return '';
    }
    
    if (isPrimitiveType(type)) {
      switch (type.value) {
        case PrimitiveTypeValue.String:
          return "''";
        case PrimitiveTypeValue.Number:
          return '0';
        case PrimitiveTypeValue.Int:
          return '0';
        case PrimitiveTypeValue.Boolean:
          return 'false';
        case PrimitiveTypeValue.Any:
          return 'null';
      }
    }
    
    if (isArrayType(type)) {
      return '[]';
    }
    
    if (isDictionaryType(type)) {
      return '{}';
    }
    
    if (isOptionalType(type)) {
      return 'null';
    }
    
    return "throw new Error('Not implemented')";
  }
}
