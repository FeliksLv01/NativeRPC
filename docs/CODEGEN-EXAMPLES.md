# NativeRPC Code Generator Examples

This document shows the code generation workflow from TypeScript interface definitions to multi-language outputs.

## Input: TypeScript Service Definition

```typescript
/**
 * Counter Service
 * 
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  /** Get the current counter value */
  getValue(): number;
  
  /** Increment the counter by 1 */
  increment(): number;
  
  /** Add a value to the counter */
  add(args: { value: number }): number;
  
  /** Get value with simulated network delay */
  getValueDelayed(args: { delayMs: number }): Promise<number>;
  
  /** Perform an async add operation */
  addAsync(args: { value: number; delayMs?: number }): Promise<CounterResult>;
  
  /** Emitted when the counter value changes */
  onCountChanged(): Event<CountChangedPayload>;
}

export interface CounterResult {
  value: number;
  timestamp: number;
  operation: CounterOperation;
}

export enum CounterOperation {
  Increment = 'increment',
  Decrement = 'decrement',
  Add = 'add',
  Reset = 'reset',
}

export interface CountChangedPayload {
  previousValue: number;
  newValue: number;
  operation: CounterOperation;
}
```

---

## Output: Kotlin (Server Stub)

```kotlin
package com.itoken.team

import com.itoken.team.nativerpc.core.NativeRPCService
import com.itoken.team.nativerpc.core.NativeRPCContext
import com.itoken.team.nativerpc.core.NativeRPCServiceFactory
import com.itoken.team.nativerpc.dsl.serviceDefinition

data class CounterResult(
    val value: Double,
    val timestamp: Double,
    val operation: CounterOperation
)

data class CountChangedPayload(
    val previousValue: Double,
    val newValue: Double,
    val operation: CounterOperation
)

enum class CounterOperation(val value: String) {
    INCREMENT("increment"),
    DECREMENT("decrement"),
    ADD("add"),
    RESET("reset");
}

class CounterRPCService(context: NativeRPCContext? = null) : NativeRPCService() {

    companion object {
        val Factory = object : NativeRPCServiceFactory<CounterRPCService> {
            override val serviceName = "counter"
            override fun create(context: NativeRPCContext?) = CounterRPCService(context)
        }
    }

    init {
        this.internalContext = context
    }

    override fun definition() = serviceDefinition {
        Function<Double>("getValue") {
            // TODO: Implement getValue
            throw NotImplementedError("Not implemented: getValue")
        }
        
        Function<Double>("increment") {
            // TODO: Implement increment
            throw NotImplementedError("Not implemented: increment")
        }
        
        Function<AddParams, Double>("add") { params ->
            // TODO: Implement add
            throw NotImplementedError("Not implemented: add")
        }
        
        AsyncFunction<GetValueDelayedParams, Double>("getValueDelayed") { params ->
            // TODO: Implement getValueDelayed
            throw NotImplementedError("Not implemented: getValueDelayed")
        }
        
        AsyncFunction<AddAsyncParams, CounterResult>("addAsync") { params ->
            // TODO: Implement addAsync
            throw NotImplementedError("Not implemented: addAsync")
        }
        
        Events("countChanged")
    }

    fun emitCountChanged(payload: CountChangedPayload) {
        emit("countChanged", payload)
    }
}

// Registration: NativeRPCServiceCenter.register(CounterRPCService.Factory)
```

---

## Output: Dart (Client)

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

class CounterResult {
  final double value;
  final double timestamp;
  final CounterOperation operation;

  const CounterResult({
    required this.value,
    required this.timestamp,
    required this.operation,
  });

  factory CounterResult.fromJson(Map<String, dynamic> json) {
    return CounterResult(
      value: (json['value'] as num).toDouble(),
      timestamp: (json['timestamp'] as num).toDouble(),
      operation: CounterOperation.fromValue(json['operation'] as String)!,
    );
  }
}

class CountChangedPayload {
  final double previousValue;
  final double newValue;
  final CounterOperation operation;

  const CountChangedPayload({
    required this.previousValue,
    required this.newValue,
    required this.operation,
  });
}

enum CounterOperation {
  increment('increment'),
  decrement('decrement'),
  add('add'),
  reset('reset');

  final String value;
  const CounterOperation(this.value);

  static CounterOperation? fromValue(String value) {
    return CounterOperation.values.cast<CounterOperation?>().firstWhere(
      (e) => e?.value == value,
      orElse: () => null,
    );
  }
}

class CounterRPCService {
  /// Get the current counter value
  static Future<double> getValue() async {
    return await NativeRPC.call<double>('counter.getValue');
  }

  /// Increment the counter by 1
  static Future<double> increment() async {
    return await NativeRPC.call<double>('counter.increment');
  }

  /// Add a value to the counter
  static Future<double> add({ required double value }) async {
    final params = <String, dynamic>{'value': value};
    return await NativeRPC.call<double>('counter.add', params);
  }

  /// Get value with simulated network delay
  static Future<double> getValueDelayed({ required double delayMs }) async {
    final params = <String, dynamic>{'delayMs': delayMs};
    return await NativeRPC.call<double>('counter.getValueDelayed', params);
  }

  /// Perform an async add operation
  static Future<CounterResult> addAsync({ required double value, double? delayMs }) async {
    final params = <String, dynamic>{'value': value, 'delayMs': delayMs};
    return await NativeRPC.call<CounterResult>('counter.addAsync', params);
  }

  /// Emitted when the counter value changes
  static Stream<dynamic> get onCountChanged {
    return NativeRPC.stream('counter.countChanged');
  }
}
```

---

## Output: TypeScript (Client)

```typescript
export interface CounterResult {
  value: number;
  timestamp: number;
  operation: CounterOperation;
}

export interface CountChangedPayload {
  previousValue: number;
  newValue: number;
  operation: CounterOperation;
}

export enum CounterOperation {
  Increment = 'increment',
  Decrement = 'decrement',
  Add = 'add',
  Reset = 'reset',
}

export class CounterRPCService {
  private readonly connection: NativeRPCConnection;

  constructor(connection: NativeRPCConnection) {
    this.connection = connection;
  }

  async getValue(): Promise<number> {
    return this.connection.call<number>('counter.getValue');
  }

  async increment(): Promise<number> {
    return this.connection.call<number>('counter.increment');
  }

  async add(params: { value: number }): Promise<number> {
    return this.connection.call<number>('counter.add', params);
  }

  async getValueDelayed(params: { delayMs: number }): Promise<number> {
    return this.connection.call<number>('counter.getValueDelayed', params);
  }

  async addAsync(params: { value: number; delayMs?: number }): Promise<CounterResult> {
    return this.connection.call<CounterResult>('counter.addAsync', params);
  }

  onCountChanged(handler: (payload: CountChangedPayload) => void): () => void {
    return this.connection.subscribe('counter.countChanged', handler);
  }
}

export interface NativeRPCConnection {
  call<T>(method: string, params?: Record<string, unknown>): Promise<T>;
  subscribe(event: string, handler: (data: unknown) => void): () => void;
}
```

---

## How Code Generator Works

### Architecture Overview

```
TypeScript Interface (@service, @serviceName)
        |
        v
    [Parser]  <-- TypeScript Compiler API (3-pass scanning)
        |
        v
    [ServiceModule]  <-- Intermediate Representation (IR)
        |
        v
    [Validator]  <-- Check types, naming conflicts
        |
        +---> [Swift Renderer]      ---> .swift (Server Stub)
        +---> [Kotlin Renderer]     ---> .kt (Server Stub)  
        +---> [Dart Renderer]       ---> .dart (Client)
        +---> [TypeScript Renderer] ---> .ts (Client)
```

### Three-Pass Parsing Strategy

| Pass | Target | Description |
|------|--------|-------------|
| Pass 1 | Enum Types | Parse all `enum` definitions |
| Pass 2 | Custom Types | Parse non-`@service` interfaces |
| Pass 3 | Service Interfaces | Parse `@service` marked interfaces |

### Method Type Inference

The generator automatically infers method types from return types:

```typescript
getValue(): number           // -> Sync method
fetchData(): Promise<Data>   // -> Async method  
onChanged(): Event<Payload>  // -> Event
reset(): void                // -> Void method
```

### Type Mapping

| TypeScript | Swift | Kotlin | Dart |
|------------|-------|--------|------|
| `string` | `String` | `String` | `String` |
| `number` | `Double` | `Double` | `double` |
| `boolean` | `Bool` | `Boolean` | `bool` |
| `T[]` | `[T]` | `List<T>` | `List<T>` |
| `T \| null` | `T?` | `T?` | `T?` |

### Incremental Merge (Swift/Kotlin)

For server stubs, the generator preserves existing implementations:

- Existing method implementations are preserved
- New methods get TODO placeholders
- Removed methods are reported (implementations will be lost)

---

## Usage

```bash
cd codegen
npm install
npm run build
npm run generate -- generate --config examples/config.json
```

### Configuration Example

```json
{
  "parsing": {
    "sources": ["./services.ts"],
    "dropInterfaceIPrefix": true
  },
  "rendering": {
    "serviceSuffix": "RPCService",
    "dart": {
      "outputPath": "./generated/dart",
      "packageName": "native_rpc_client"
    },
    "typescript": {
      "outputPath": "./generated/typescript",
      "useESModules": true
    },
    "kotlin": {
      "outputPath": "./generated/kotlin",
      "packageName": "com.itoken.team",
      "imports": ["com.itoken.team.nativerpc.*"],
      "baseClass": "NativeRPCService"
    }
  }
}
```

---

## Summary

| Output | Type | Purpose |
|--------|------|---------|
| **Kotlin** | Server Stub | DSL-based service definition with Factory pattern |
| **Dart** | Client | Static methods, Stream-based event subscription |
| **TypeScript** | Client | Connection-injected instance methods |

The code generator provides:

1. **Type Safety** - Generated code is fully typed
2. **Incremental Updates** - Server stubs preserve existing implementations
3. **Multi-Platform** - Single source generates all platforms
4. **Convention over Configuration** - Sensible defaults with customization options
