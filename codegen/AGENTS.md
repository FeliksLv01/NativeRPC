# AGENTS - NativeRPC Code Generator

This document explains the architecture, working principles, and implementation details of the code generator for developers to understand and maintain.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Data Flow](#core-data-flow)
3. [Parser Principles](#parser-principles)
4. [Renderer Principles](#renderer-principles)
5. [Type Conversion System](#type-conversion-system)
6. [Incremental Merge Mechanism](#incremental-merge-mechanism)
7. [Configuration System](#configuration-system)
8. [File Structure](#file-structure)

---

## Architecture Overview

NativeRPC Code Generator is a tool that generates multi-language code from TypeScript interface definitions. It uses the classic **Parse-Transform-Render** three-stage architecture:

```
TypeScript Interfaces (@service, @serviceName)
        |
        v
    [Parser] (Three-pass parsing)
        |
        v
    [ServiceModule] (Intermediate Representation)
        |
        v
    [Validator] (Check types, naming conflicts, enums)
        |
        +---> [Swift Renderer + Merger] ---> .swift Service
        +---> [Kotlin Renderer + Merger] --> .kt Service  
        +---> [Dart Renderer] --------------> .dart Client
        +---> [TypeScript Renderer] --------> .ts Client
```

### Core Components

| Component | File | Responsibility |
|-----------|------|----------------|
| **Parser** | `src/parser/index.ts` | Parse interface definitions using TypeScript Compiler API |
| **Validator** | `src/validator/index.ts` | Validate service definition correctness |
| **Renderers** | `src/renderer/index.ts` | Render ServiceModule to target language code |
| **TypeTransformers** | `src/renderer/type-transformer.ts` | Type name conversion (TS → target language) |
| **Mergers** | `src/merger/index.ts` | Swift/Kotlin incremental updates, preserve existing implementations |

---

## Core Data Flow

### 1. Input: TypeScript Interface Definition

```typescript
/**
 * Counter Service
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  /** Get current value */
  getValue(): number;
  
  /** Async get value */
  fetchValue(): Promise<number>;
  
  /** Value changed event */
  onValueChanged(): Event<{ oldValue: number; newValue: number }>;
}
```

### 2. Intermediate Representation: ServiceModule

After parsing, a unified IR is generated:

```typescript
interface ServiceModule {
  name: string;              // "CounterService"
  serviceName: string;       // "counter" (from @serviceName)
  documentation: string;     // "Counter Service"
  methods: ServiceMethod[];  // All methods (sync/async)
  events: ServiceEvent[];    // All events
  customTypes: CustomType[]; // Referenced custom types
  enums: EnumType[];         // Referenced enum types
}
```

### 3. Output: Multi-language Code

Generate platform-specific code from ServiceModule:

| Platform | File Type | Purpose |
|----------|-----------|---------|
| **Swift** | Service Stub | iOS/macOS server-side implementation |
| **Kotlin** | Service Stub | Android server-side implementation |
| **Dart** | Client | Flutter client calls |
| **TypeScript** | Client | Web client calls |

---

## Parser Principles

The parser is located at `src/parser/index.ts` and uses TypeScript Compiler API for three-pass scanning:

### Three-Pass Parsing Strategy

**Pass 1: Enum Types**
- Parse all enum definitions
- Build enum name → EnumType mapping

**Pass 2: Custom Types**
- Parse all non-service interfaces
- Parse field types (can reference already parsed enums)
- Build type name → CustomType mapping

**Pass 3: Service Interfaces**
- Identify interfaces marked with @service
- Parse method signatures and return types
- Parse event definitions (Event<T>)
- Collect dependent types and enums

### Method Type Inference

Automatically infer method kind from return type:

```typescript
function inferMethodKind(returnType: string): MethodKind {
  if (returnType.startsWith('Promise<')) {
    return MethodKind.Async;
  } else if (returnType.startsWith('Event<')) {
    return MethodKind.Event;  // Actually parsed as ServiceEvent
  } else if (returnType === 'void') {
    return MethodKind.Void;
  } else {
    return MethodKind.Sync;
  }
}
```

### Type System

All types are uniformly represented as `ValueType` union type:

```typescript
type ValueType = 
  | PrimitiveType      // string, number, boolean, Int, Date, etc.
  | ArrayType          // Array<T>
  | OptionalType       // T | null, T?
  | CustomType         // Custom interface/class
  | EnumType           // Enum
  | VoidType           // void
  | UnknownType;       // Unknown type
```

### Inline Type Naming

For inline object types in method parameters and event payloads, generate meaningful names:

```typescript
// Input
onValueChanged(): Event<{ oldValue: number; newValue: number }>;

// Generated type name
ValueChangedPayload  // Instead of InlineType1
```

Naming rules:
- Event payload: `{EventName}Payload` → `ValueChangedPayload`
- Method params: `{MethodName}Params` → `GetValueParams`
- Method result: `{MethodName}Result` → `GetValueResult`

---

## Renderer Principles

Renderers are located at `src/renderer/index.ts` and use Mustache template engine.

### Renderer Class Hierarchy

```
ServiceRenderer (abstract)
    ├── SwiftRenderer (+renderWithMerge)
    ├── KotlinRenderer (+renderWithMerge)
    ├── DartRenderer
    └── TypeScriptRenderer
```

### Base Class Responsibilities

```typescript
abstract class ServiceRenderer {
  protected templateDir: string;
  protected transformer: TypeTransformer;
  protected jsonConverter: JsonConverterGenerator;
  protected serviceSuffix: string;
  
  render(module: ServiceModule, templateName: string): string;
  
  protected getServiceClassName(moduleName: string): string {
    const baseName = moduleName.replace(/Service$/, '');
    return `${baseName}${this.serviceSuffix}`;  // e.g., "CounterRPCService"
  }
}
```

### Service Naming Rules

Service class name generation:

```
Input interface: ICounterService
        ↓
Remove I prefix: CounterService  (if dropInterfaceIPrefix: true)
        ↓
Remove Service suffix: Counter
        ↓
Add configured suffix: Counter + "RPCService" = CounterRPCService
```

**Config option:** `rendering.serviceSuffix` (default: `"RPCService"`)

### File Naming Rules

| Language | File Name Format | Example |
|----------|-----------------|---------|
| Swift | `{ClassName}.swift` | `CounterRPCService.swift` |
| Kotlin | `{ClassName}.kt` | `CounterRPCService.kt` |
| Dart | `{snake_case}.dart` | `counter_rpc_service.dart` |
| TypeScript | `{kebab-case}.ts` | `counter-rpc-service.ts` |

---

## Type Conversion System

Type transformers are located at `src/renderer/type-transformer.ts`.

### Type Mapping

| TypeScript | Swift | Kotlin | Dart | TypeScript (output) |
|------------|-------|--------|------|---------------------|
| `string` | `String` | `String` | `String` | `string` |
| `number` | `Double` | `Double` | `double` | `number` |
| `Int` | `Int` | `Int` | `int` | `number` |
| `boolean` | `Bool` | `Boolean` | `bool` | `boolean` |
| `Date` | `Date` | `Date` | `DateTime` | `Date` |
| `T[]` | `[T]` | `List<T>` | `List<T>` | `T[]` |
| `T \| null` | `T?` | `T?` | `T?` | `T \| null` |

---

## Incremental Merge Mechanism

The incremental merger is located at `src/merger/index.ts` and is used for Swift and Kotlin code updates.

### Workflow

1. Parse existing file to extract method implementations
2. Generate new code with updated method signatures
3. **Preserve** all existing implementation code inside `{ }`
4. Add TODO placeholders for new methods
5. Report removed methods (their implementations will be lost)

### Merge Result Example

```
=== Method Diff Report ===

➕ Added methods:
   + newMethod          // New, generates TODO placeholder

➖ Removed methods (implementation will be lost):
   - deprecatedMethod   // Removed, warns user

✓ 5 methods unchanged   // Original implementation preserved
```

---

## Configuration System

Configuration types are defined in `src/config.ts`.

### Complete Configuration Structure

```typescript
interface Configuration {
  parsing: ParsingConfiguration;
  rendering: RenderingConfiguration;
}

interface ParsingConfiguration {
  sources: string[];              // Source file glob patterns
  tsconfigPath?: string;          // tsconfig path
  predefinedTypes?: string[];     // Predefined types (don't parse)
  dropInterfaceIPrefix?: boolean; // Remove interface I prefix
}

interface RenderingConfiguration {
  serviceSuffix?: string;         // Service class name suffix (default "RPCService")
  dart?: DartRenderConfiguration;
  typescript?: TypeScriptRenderConfiguration;
  swift?: SwiftRenderConfiguration;
  kotlin?: KotlinRenderConfiguration;
}
```

---

## File Structure

```
codegen/
├── src/
│   ├── index.ts                    # Main entry, NativeRPCCodeGenerator class
│   ├── types.ts                    # Core type definitions
│   ├── config.ts                   # Configuration types
│   ├── cli/
│   │   └── index.ts                # CLI implementation (Commander.js)
│   ├── parser/
│   │   └── index.ts                # TypeScript parser
│   ├── validator/
│   │   └── index.ts                # Service definition validation
│   ├── renderer/
│   │   ├── index.ts                # Renderer base class and implementations
│   │   └── type-transformer.ts     # Type transformers
│   └── merger/
│       └── index.ts                # Incremental merge logic
│
├── templates/
│   ├── dart/                       # Dart templates
│   ├── kotlin/                     # Kotlin templates
│   ├── swift/                      # Swift templates
│   └── typescript/                 # TypeScript templates
│
├── examples/
│   ├── services.ts                 # Example service definitions
│   └── config.json                 # Example configuration
│
├── generated/                      # Generated code output directory
├── bin/
│   └── nativerpc-codegen           # CLI entry script
│
├── package.json
├── tsconfig.json
├── README.md                       # User documentation (English)
├── README.zh-CN.md                 # User documentation (Chinese)
└── AGENTS.md                       # This document (Developer documentation)
```

---

## CLI Commands

```bash
# Generate all platform code
npm run generate -- generate --config examples/config.json

# Preview mode (don't write files)
npm run generate -- generate --config examples/config.json --dry-run

# Generate specific platforms only
npm run generate -- generate --config examples/config.json --swift --kotlin

# Initialize configuration file
npm run generate -- init

# View diff report
npm run generate -- diff --config examples/config.json
```

---

## Extension Guide

### Adding New Language Support

1. **Create TypeTransformer subclass**
2. **Create Renderer subclass**
3. **Create Mustache templates**
4. **Register in index.ts**

### Custom Templates

Specify custom template path in configuration:

```json
{
  "rendering": {
    "swift": {
      "templatePath": "./my-templates/custom-swift.mustache"
    }
  }
}
```

---

## Related Resources

- **Main SDK**: `../sdk/`
- **Flutter Connection**: `../connections/flutter/`
- **Architecture Docs**: `../docs/CODEGEN-ARCHITECTURE.md`
- **Inspiration**: [ts-gyb](https://github.com/nicklockwood/ts-gyb)
