# NativeRPC 代码生成器示例

本文档展示从 TypeScript 接口定义到多语言输出的代码生成流程。

## 输入: TypeScript 服务定义

```typescript
/**
 * Counter Service
 * 
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  /** 获取当前计数值 */
  getValue(): number;
  
  /** 计数器加 1 */
  increment(): number;
  
  /** 给计数器加一个值 */
  add(args: { value: number }): number;
  
  /** 模拟网络延迟获取值 */
  getValueDelayed(args: { delayMs: number }): Promise<number>;
  
  /** 异步加法操作 */
  addAsync(args: { value: number; delayMs?: number }): Promise<CounterResult>;
  
  /** 计数值变化时触发 */
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

## 输出: Kotlin (服务端 Stub)

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
            // TODO: 实现 getValue
            throw NotImplementedError("Not implemented: getValue")
        }
        
        Function<Double>("increment") {
            // TODO: 实现 increment
            throw NotImplementedError("Not implemented: increment")
        }
        
        Function<AddParams, Double>("add") { params ->
            // TODO: 实现 add
            throw NotImplementedError("Not implemented: add")
        }
        
        AsyncFunction<GetValueDelayedParams, Double>("getValueDelayed") { params ->
            // TODO: 实现 getValueDelayed
            throw NotImplementedError("Not implemented: getValueDelayed")
        }
        
        AsyncFunction<AddAsyncParams, CounterResult>("addAsync") { params ->
            // TODO: 实现 addAsync
            throw NotImplementedError("Not implemented: addAsync")
        }
        
        Events("countChanged")
    }

    fun emitCountChanged(payload: CountChangedPayload) {
        emit("countChanged", payload)
    }
}

// 注册: NativeRPCServiceCenter.register(CounterRPCService.Factory)
```

---

## 输出: Dart (客户端)

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
  /// 获取当前计数值
  static Future<double> getValue() async {
    return await NativeRPC.call<double>('counter.getValue');
  }

  /// 计数器加 1
  static Future<double> increment() async {
    return await NativeRPC.call<double>('counter.increment');
  }

  /// 给计数器加一个值
  static Future<double> add({ required double value }) async {
    final params = <String, dynamic>{'value': value};
    return await NativeRPC.call<double>('counter.add', params);
  }

  /// 模拟网络延迟获取值
  static Future<double> getValueDelayed({ required double delayMs }) async {
    final params = <String, dynamic>{'delayMs': delayMs};
    return await NativeRPC.call<double>('counter.getValueDelayed', params);
  }

  /// 异步加法操作
  static Future<CounterResult> addAsync({ required double value, double? delayMs }) async {
    final params = <String, dynamic>{'value': value, 'delayMs': delayMs};
    return await NativeRPC.call<CounterResult>('counter.addAsync', params);
  }

  /// 计数值变化时触发
  static Stream<dynamic> get onCountChanged {
    return NativeRPC.stream('counter.countChanged');
  }
}
```

---

## 输出: TypeScript (客户端)

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

## 代码生成器工作原理

### 架构概览

```mermaid
flowchart TB
    subgraph Input
        TS["TypeScript 接口<br/>@service, @serviceName"]
    end
    
    subgraph Processing
        Parser["Parser<br/><small>TypeScript Compiler API</small>"]
        IR["ServiceModule<br/><small>中间表示 IR</small>"]
        Validator["Validator<br/><small>校验类型、命名冲突</small>"]
    end
    
    subgraph Renderers
        Swift["Swift Renderer"]
        Kotlin["Kotlin Renderer"]
        Dart["Dart Renderer"]
        TSRenderer["TS Renderer"]
    end
    
    subgraph Output
        SwiftFile[".swift<br/><small>服务端</small>"]
        KotlinFile[".kt<br/><small>服务端</small>"]
        DartFile[".dart<br/><small>客户端</small>"]
        TSFile[".ts<br/><small>客户端</small>"]
    end
    
    TS --> Parser
    Parser --> IR
    IR --> Validator
    Validator --> Swift
    Validator --> Kotlin
    Validator --> Dart
    Validator --> TSRenderer
    Swift --> SwiftFile
    Kotlin --> KotlinFile
    Dart --> DartFile
    TSRenderer --> TSFile
```

---

### 第一步：TypeScript 代码分析 (Parser)

代码生成器使用 **TypeScript Compiler API** 分析源代码，通过 AST（抽象语法树）提取类型信息。

#### 三遍扫描策略

```mermaid
flowchart LR
    subgraph "Pass 1"
        E1[扫描 enum] --> E2[收集枚举定义]
    end
    
    subgraph "Pass 2"
        T1[扫描 interface] --> T2{有 @service?}
        T2 -->|否| T3[作为自定义类型收集]
        T2 -->|是| T4[跳过，等 Pass 3]
    end
    
    subgraph "Pass 3"
        S1[扫描 @service 接口] --> S2[解析方法签名]
        S2 --> S3[解析事件定义]
        S3 --> S4[关联依赖类型]
    end
    
    E2 --> T1
    T3 --> S1
    T4 --> S1
```

| 遍次 | 目标 | 说明 |
|------|------|------|
| Pass 1 | Enum 类型 | 解析所有 `enum` 定义，建立 enum 名称映射 |
| Pass 2 | 自定义类型 | 解析非 `@service` 的 interface，此时可以引用已解析的 enum |
| Pass 3 | 服务接口 | 解析 `@service` 标记的 interface，收集方法、事件、依赖类型 |

#### 解析过程示例

```typescript
// 输入
export interface ICounterService {
  getValue(): number;
  addAsync(args: { value: number }): Promise<CounterResult>;
  onCountChanged(): Event<CountChangedPayload>;
}
```

Parser 使用 `ts.createProgram()` 创建程序，然后遍历 AST：

```typescript
// 1. 创建 TypeScript 程序
const program = ts.createProgram(filePaths, compilerOptions);
const checker = program.getTypeChecker();

// 2. 遍历 AST 节点
ts.forEachChild(sourceFile, node => {
  if (ts.isInterfaceDeclaration(node)) {
    // 检查 JSDoc 标签
    const symbol = checker.getSymbolAtLocation(node.name);
    const jsDocTags = symbol.getJsDocTags(); // 获取 @service, @serviceName
    
    // 遍历接口成员
    for (const member of node.members) {
      if (ts.isMethodSignature(member)) {
        // 解析方法签名
        const returnType = member.type.getText(); // "number", "Promise<T>", "Event<T>"
      }
    }
  }
});
```

#### 方法类型自动推断

Parser 根据返回类型自动识别方法类型：

```typescript
// 根据返回类型推断方法类型
getValue(): number           // → 同步方法 (MethodKind.Sync)
fetchData(): Promise<Data>   // → 异步方法 (MethodKind.Async)
onChanged(): Event<Payload>  // → 事件 (转为 ServiceEvent)
reset(): void                // → Void 方法 (MethodKind.Void)
```

#### 中间表示 (ServiceModule)

解析后生成统一的 IR 结构：

```typescript
interface ServiceModule {
  name: string;              // "CounterService"
  serviceName: string;       // "counter" (来自 @serviceName)
  documentation: string;     // JSDoc 注释
  methods: ServiceMethod[];  // 所有方法（同步、异步、void）
  events: ServiceEvent[];    // 所有事件
  customTypes: CustomType[]; // 依赖的自定义类型
  enums: EnumType[];         // 依赖的枚举
}
```

---

### 第二步：代码生成 (Renderer)

每种目标语言有独立的 **Renderer**，使用 **Mustache 模板引擎** 生成代码。

#### 生成流程

```mermaid
flowchart LR
    IR[ServiceModule] --> TT[TypeTransformer<br/>类型转换]
    TT --> VM[TemplateView<br/>视图模型]
    VM --> MT[Mustache 模板]
    MT --> Code[生成代码]
```

#### 1. 类型转换 (TypeTransformer)

每种语言有独立的类型转换器，将 IR 中的抽象类型转为目标语言类型：

```typescript
// Swift 类型转换器
class SwiftTypeTransformer {
  convert(type: ValueType): string {
    if (type.kind === 'primitive') {
      switch (type.value) {
        case 'string':  return 'String';
        case 'number':  return 'Double';
        case 'boolean': return 'Bool';
      }
    }
    if (type.kind === 'array') {
      return `[${this.convert(type.elementType)}]`;
    }
    if (type.kind === 'optional') {
      return `${this.convert(type.wrappedType)}?`;
    }
    // ...
  }
}
```

**类型映射表：**

| TypeScript | Swift | Kotlin | Dart |
|------------|-------|--------|------|
| `string` | `String` | `String` | `String` |
| `number` | `Double` | `Double` | `double` |
| `boolean` | `Bool` | `Boolean` | `bool` |
| `T[]` | `[T]` | `List<T>` | `List<T>` |
| `T \| null` | `T?` | `T?` | `T?` |

#### 2. 视图模型 (TemplateView)

Renderer 将 IR 转换为 Mustache 友好的视图模型：

```typescript
interface TemplateView {
  className: string;        // "CounterRPCService"
  serviceName: string;      // "counter"
  syncMethods: MethodView[];
  asyncMethods: MethodView[];
  events: EventView[];
  customTypes: CustomTypeView[];
  enums: EnumView[];
}
```

#### 3. Mustache 模板

模板使用 `{{}}` 语法插入变量，`{{#}}` 遍历数组：

```mustache
// Kotlin 模板示例 (templates/kotlin/service.mustache)
class {{className}}(context: NativeRPCContext? = null) : NativeRPCService() {
    
    override fun definition() = serviceDefinition {
        {{#syncMethods}}
        Function<{{returnType}}>("{{methodName}}") {
            // TODO: Implement {{methodName}}
        }
        {{/syncMethods}}
        
        {{#asyncMethods}}
        AsyncFunction<{{returnType}}>("{{methodName}}") {
            // TODO: Implement {{methodName}}
        }
        {{/asyncMethods}}
        
        {{#events}}
        Events("{{eventName}}")
        {{/events}}
    }
}
```

#### 4. 渲染输出

Mustache 将 TemplateView 数据填充到模板中：

```typescript
// Renderer 核心代码
render(module: ServiceModule): string {
  const template = fs.readFileSync(templatePath, 'utf-8');
  const view = this.buildView(module);  // IR → TemplateView
  return Mustache.render(template, view);
}
```

---

### 第三步：增量合并 (Merger)

Swift/Kotlin 服务端 Stub 支持**增量更新**，保留手写的方法实现。

#### 合并流程

```mermaid
flowchart TB
    A[读取已有文件] --> B[解析方法实现]
    B --> C[生成新代码结构]
    C --> D{方法是否存在?}
    D -->|存在| E[保留原有实现]
    D -->|新增| F[生成 TODO 占位]
    D -->|删除| G[报告警告]
    E --> H[输出合并后代码]
    F --> H
```

#### 示例

假设原有实现：

```kotlin
Function<Double>("getValue") {
    return counter.value  // 手写的实现
}
```

重新生成后，实现代码被保留：

```kotlin
Function<Double>("getValue") {
    return counter.value  // 实现被保留！
}

Function<Double>("newMethod") {
    // TODO: Implement newMethod  // 新方法生成 TODO
}
```

---

### 完整处理流程

```mermaid
sequenceDiagram
    participant TS as TypeScript 源码
    participant Parser as Parser
    participant IR as ServiceModule
    participant TT as TypeTransformer
    participant TPL as Mustache 模板
    participant Output as 输出文件
    
    TS->>Parser: 读取源文件
    Parser->>Parser: Pass 1: 收集 enum
    Parser->>Parser: Pass 2: 收集 interface
    Parser->>Parser: Pass 3: 解析 @service
    Parser->>IR: 生成 ServiceModule
    
    IR->>TT: 转换类型
    TT->>TPL: 填充模板变量
    TPL->>Output: 渲染生成代码
```

---

## 使用方法

```bash
cd codegen
npm install
npm run build
npm run generate -- generate --config examples/config.json
```

### 配置文件示例

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

## 总结

| 输出 | 类型 | 用途 |
|------|------|------|
| **Kotlin** | 服务端 Stub | 基于 DSL 的服务定义，Factory 模式，事件发送器 |
| **Dart** | 客户端 | 静态方法调用，Stream 事件订阅 |
| **TypeScript** | 客户端 | 基于 Connection 实例的方法调用 |

代码生成器的特性：

1. **类型安全** - 生成的代码完全类型化
2. **增量更新** - 服务端 Stub 保留已有实现
3. **多平台** - 单一源文件生成所有平台代码
4. **约定优于配置** - 合理的默认值，支持自定义
