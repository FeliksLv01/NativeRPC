# NativeRPC Code Generator

Generate type-safe clients and service stubs from TypeScript service definitions.

## Features

- **TypeScript-First**: Define your services using TypeScript interfaces - more intuitive than YAML/JSON
- **Multi-Platform Output**: Generate code for Dart, TypeScript (Web), Swift, and Kotlin
- **Incremental Updates**: Swift/Kotlin generators preserve your method implementations
- **Type Safety**: Generated clients are fully typed with proper parameter and return types
- **Event Support**: First-class support for event subscriptions
- **Configurable Naming**: Customize service class names, file names, and package names

## Installation

```bash
npm install nativerpc-codegen
# or
yarn add nativerpc-codegen
```

## Quick Start

### 1. Define Your Services

Create a TypeScript file with your service definitions:

```typescript
// services.ts

/**
 * Counter statistics
 */
export interface CounterStats {
  incrementCount: number;
  decrementCount: number;
  peakValue: number;
}

/**
 * Counter Service
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  // Synchronous method (returns value directly)
  getValue(): number;
  
  // Method with parameters
  add(args: { value: number }): number;
  
  // Async method (returns Promise)
  getValueDelayed(args: { delayMs: number }): Promise<number>;
  
  // Event (returns Event<PayloadType>)
  onCountChanged(): Event<{ oldValue: number; newValue: number }>;
}

// Event type marker
export type Event<T> = { __eventPayload: T };
```

### 2. Create Configuration

Create a `nativerpc.config.json`:

```json
{
  "parsing": {
    "sources": ["./services.ts"],
    "dropInterfaceIPrefix": true
  },
  "rendering": {
    "serviceSuffix": "RPCService",
    "dart": {
      "outputPath": "./generated/dart"
    },
    "swift": {
      "outputPath": "./generated/swift",
      "existingServicePath": "./ios/Services",
      "imports": ["NativeRPCKit"],
      "baseClass": "NativeRPCService"
    },
    "kotlin": {
      "outputPath": "./generated/kotlin",
      "existingServicePath": "./android/app/src/main/java/services",
      "packageName": "com.itoken.team"
    },
    "typescript": {
      "outputPath": "./generated/typescript"
    }
  }
}
```

### 3. Generate Code

```bash
npx nativerpc-codegen generate --config nativerpc.config.json

# Dry run (preview without writing files)
npx nativerpc-codegen generate --config nativerpc.config.json --dry-run
```

## Generated Output

With `serviceSuffix: "RPCService"`, the generator produces:

| Language | File Name | Class Name |
|----------|-----------|------------|
| Swift | `CounterRPCService.swift` | `CounterRPCService` |
| Kotlin | `CounterRPCService.kt` | `CounterRPCService` |
| Dart | `counter_rpc_service.dart` | `CounterRPCService` |
| TypeScript | `counter-rpc-service.ts` | `CounterRPCService` |

### Dart (Flutter Client)

```dart
class CounterRPCService {
  final NativeRPCClient _client;

  Future<int> getValue() async {
    return await _client.call<int>('counter.getValue');
  }

  Future<int> add({ required int value }) async {
    final params = { 'value': value };
    return await _client.call<int>('counter.add', params);
  }

  Stream<CountChangedPayload> get onCountChangedStream {
    return _client.subscribeStream('counter.countChanged');
  }
}
```

### Swift (Service Stub)

```swift
final class CounterRPCService: NativeRPCService {
    override var definition: ServiceDefinition {
        Service("counter") {
            Function("getValue") { () -> Int in
                // Your implementation here
            }
            
            Function("add") { (value: Int) -> Int in
                // Your implementation here
            }
            
            AsyncFunction("getValueDelayed") { (delayMs: Int) async throws -> Int in
                // Your implementation here
            }
            
            Event("countChanged")
        }
    }
    
    func emitCountChanged(_ payload: CountChangedPayload) {
        emit("countChanged", data: payload)
    }
}
```

### Kotlin (Service Stub)

```kotlin
package com.itoken.team

class CounterRPCService : NativeRPCService("counter") {
    override fun definition() = service {
        function("getValue") { ->
            // Your implementation here
        }
        
        function("add") { value: Int ->
            // Your implementation here
        }
        
        suspendFunction("getValueDelayed") { delayMs: Int ->
            // Your implementation here
        }
        
        event("countChanged")
    }
    
    fun emitCountChanged(payload: CountChangedPayload) {
        emit("countChanged", payload)
    }
}
```

## Method Types

The generator infers method types from return types:

| TypeScript Return Type | Method Kind | Generated Code |
|------------------------|-------------|----------------|
| `T` (any non-Promise) | Sync | `Function` / `function` |
| `Promise<T>` | Async | `AsyncFunction` / `suspendFunction` |
| `void` | Void | `Function` (no return) |
| `Event<T>` | Event | `Event` definition + emit helper |

## Incremental Updates

When regenerating Swift/Kotlin code, the generator:

1. Parses the existing file to extract method implementations
2. Generates new code with updated method signatures
3. **Preserves** all existing implementation code inside `{ }`
4. Adds TODO placeholders for new methods
5. Reports removed methods (their implementations will be lost)

### Example Output

```
=== Method Diff Report ===

➕ Added methods:
   + newMethod

➖ Removed methods (implementation will be lost):
   - deprecatedMethod

✓ 5 methods unchanged
```

## Configuration Reference

### `parsing`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sources` | `string[]` | Required | Glob patterns for TypeScript source files |
| `tsconfigPath` | `string` | - | Path to tsconfig.json |
| `dropInterfaceIPrefix` | `boolean` | `false` | Remove 'I' prefix from interface names |
| `predefinedTypes` | `string[]` | - | Types to not parse (e.g., `["Date", "URL"]`) |

### `rendering`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `serviceSuffix` | `string` | `"RPCService"` | Suffix for generated service class names |

### `rendering.dart`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outputPath` | `string` | Required | Output directory |
| `packageName` | `string` | - | Package name for imports |
| `templatePath` | `string` | - | Custom template path |

### `rendering.typescript`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outputPath` | `string` | Required | Output directory |
| `useESModules` | `boolean` | `false` | Use ES modules syntax |
| `templatePath` | `string` | - | Custom template path |

### `rendering.swift`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outputPath` | `string` | Required | Output directory |
| `existingServicePath` | `string` | - | Path to existing services for incremental merge |
| `imports` | `string[]` | - | Import statements to include |
| `baseClass` | `string` | - | Base class for services |
| `templatePath` | `string` | - | Custom template path |

### `rendering.kotlin`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `outputPath` | `string` | Required | Output directory |
| `existingServicePath` | `string` | - | Path to existing services for incremental merge |
| `packageName` | `string` | `"com.itoken.team"` | Kotlin package name |
| `imports` | `string[]` | - | Import statements to include |
| `baseClass` | `string` | - | Base class for services |
| `templatePath` | `string` | - | Custom template path |

## Custom Templates

You can provide custom Mustache templates:

```json
{
  "rendering": {
    "swift": {
      "templatePath": "./my-templates/swift-service.mustache"
    }
  }
}
```

See `templates/` directory for built-in templates.

## CLI Commands

```bash
# Generate all platforms
nativerpc-codegen generate --config config.json

# Dry run (preview without writing)
nativerpc-codegen generate --config config.json --dry-run

# Generate specific platforms only
nativerpc-codegen generate --config config.json --swift --kotlin

# Initialize a new config file
nativerpc-codegen init

# Show diff report (what would change)
nativerpc-codegen diff --config config.json
```

## License

MIT
