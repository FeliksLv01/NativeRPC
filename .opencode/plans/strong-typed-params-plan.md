# NativeRPC: 强类型 Params + Response 迁移计划

> **状态**: ✅ 全部完成！Phase 1, 2, 3 (Android 统一), 3.5 (示例更新), 4 (集成测试) 已完成  
> **创建时间**: 2024-01  
> **更新时间**: 2026-02-02
> **目标**: 用 Codable 替代当前的 tuple 参数解析，实现类型安全的请求/响应处理

## 完成进度

### Phase 1: iOS SDK 重构 ✅ 已完成

| # | 任务 | 状态 |
|---|------|------|
| 1.1 | 重构 `SyncFunctionDefinition` 使用 Codable | ✅ 完成 |
| 1.2 | 重构 `AsyncFunctionDefinition` 使用 Codable | ✅ 完成 |
| 1.3 | 移除 `PromiseAsyncFunctionDefinition` | ✅ 完成 |
| 1.4 | 移除 `tupleFromArray()` 函数 | ✅ 完成 |
| 1.5 | 简化 `DSLFactories.swift` 为 8 个函数 | ✅ 完成 |
| 1.6 | 删除 `Promise.swift` | ✅ 完成 |
| 1.7 | 更新 `CounterService.swift` | ✅ 完成 |
| 1.8 | 更新测试用例 | ✅ 完成 |
| 1.9 | 运行 `swift test` 验证 | ✅ 27 tests passed |

### Phase 2: Swift Codegen 增强 ✅ 已完成

| # | 任务 | 状态 |
|---|------|------|
| 2.1 | 添加 `methodNamePascal` 到 MethodView | ✅ 完成 |
| 2.2 | 添加 `allMethods` 视图（包含所有方法） | ✅ 完成 |
| 2.3 | 创建 `swift-params.mustache` 模板 | ✅ 完成 |
| 2.4 | 更新 `service.mustache` 使用新语法 | ✅ 完成 |
| 2.5 | 添加 `renderTypesExtension` 方法 | ✅ 完成 |
| 2.6 | 更新主生成器生成多文件 | ✅ 完成 |
| 2.7 | 添加顶层 `className` 到 TemplateView | ✅ 完成 |

### Phase 2.5: Kotlin Codegen 修复 ✅ 已完成 (已被 Phase 3 取代)

> **注意**: 此阶段的工作（FunctionN 语法）已被 Phase 3 取代，现在 Android 使用和 iOS 相同的 Params 模式。

### Phase 3: Android SDK 统一 Params 模式 ✅ 已完成

| # | 任务 | 状态 |
|---|------|------|
| 3.1 | 添加 Gson 依赖用于 JSON 解析 | ✅ 完成 |
| 3.2 | 重构 `SyncFunctionDefinition` 使用 Codable 模式 | ✅ 完成 |
| 3.3 | 重构 `AsyncFunctionDefinition` 使用 Codable 模式 | ✅ 完成 |
| 3.4 | 添加 `VoidParams` / `VoidResult` 类型 | ✅ 完成 |
| 3.5 | 简化 `ServiceDefinitionBuilder` (4 个新函数，旧 FunctionN 标记废弃) | ✅ 完成 |
| 3.6 | 更新 Kotlin codegen 模板使用 Params 模式 | ✅ 完成 |
| 3.7 | 生成 Params data class 在服务文件中 | ✅ 完成 |
| 3.8 | iOS SDK 测试验证 | ✅ 27 tests passed |

### Phase 3.5: 示例与文档更新 ✅ 已完成

| # | 任务 | 状态 |
|---|------|------|
| 3.5.1 | 更新 Flutter example Android CounterService | ✅ 完成 |
| 3.5.2 | 更新 sdk/android/AGENTS.md 文档 | ✅ 完成 |
| 3.5.3 | 添加 Android SDK 单元测试 | ✅ 完成 |

### Phase 4: 集成测试 ✅ 已完成

| # | 任务 | 状态 |
|---|------|------|
| 4.1 | 运行 iOS SDK 测试 | ✅ 27 tests passed |
| 4.2 | 运行 Codegen 验证 | ✅ 10 files generated |
| 4.3 | 端到端 Flutter 测试 (iOS 模拟器) | ✅ App launched successfully |
| 4.4 | 验证服务注册和调用 | ✅ CounterService with Params pattern works |

#### 统一后的 API 对比

**iOS (Swift):**
```swift
// 无参数
Function("getValue") { () -> Double in ... }

// 有参数
Function("add") { (params: AddParams) -> Double in ... }

// 异步
AsyncFunction("fetchData") { (params: FetchParams) async throws -> Data in ... }
```

**Android (Kotlin):**
```kotlin
// 无参数
Function<Double>("getValue") { ... }

// 有参数
Function<AddParams, Double>("add") { params -> ... }

// 异步
AsyncFunction<FetchParams, Data>("fetchData") { params -> ... }
```

#### Kotlin Codegen 生成示例（新）

```kotlin
// Params data class (自动生成)
data class AddParams(
    val value: Double
)

data class AddTwoParams(
    val a: Double,
    val b: Double
)

// Service definition
override fun definition() = serviceDefinition {
    // 无参数
    Function<Double>("getValue") {
        // TODO: Implement getValue
        throw NotImplementedError("Not implemented: getValue")
    }
    
    // 有参数
    Function<AddParams, Double>("add") { params ->
        // TODO: Implement add
        // Available: params.value
        throw NotImplementedError("Not implemented: add")
    }
    
    // 多参数（打包到一个 data class）
    Function<AddTwoParams, Double>("addTwo") { params ->
        // TODO: Implement addTwo
        // Available: params.a, params.b
        throw NotImplementedError("Not implemented: addTwo")
    }
    
    // 异步有参数
    AsyncFunction<GetValueDelayedParams, Double>("getValueDelayed") { params ->
        // TODO: Implement getValueDelayed
        throw NotImplementedError("Not implemented: getValueDelayed")
    }
    
    // 异步无参数
    AsyncFunction<CounterResult>("fetchRemoteValue") {
        // TODO: Implement fetchRemoteValue
        throw NotImplementedError("Not implemented: fetchRemoteValue")
    }
}
```

#### Codegen 生成文件

Swift codegen 现在为每个服务生成两个文件：

| 文件 | 用途 | 示例 |
|------|------|------|
| `{Service}.swift` | 服务骨架（增量合并） | `CounterRPCService.swift` |
| `{Service}+Types.swift` | Params 类型定义 | `CounterRPCService+Types.swift` |

生成代码示例：

```swift
// CounterRPCService.swift
Function("addTwo") { (params: AddTwoParams) -> Double in
    // TODO: Implement addTwo
    // Available params: params.a, params.b
    fatalError("Not implemented: addTwo")
}

// CounterRPCService+Types.swift
extension CounterRPCService {
    struct AddTwoParams: Codable {
        let a: Double
        let b: Double
    }
}
```

### 关键变更总结

1. **新增类型**: `VoidParams`, `VoidResult` (替代直接使用 `Void`)
2. **DSL 工厂函数**: 从 18 个简化为 8 个 (4 sync + 4 async)
3. **Promise 支持**: 已移除，统一使用 async/await
4. **参数解析**: 使用 JSONDecoder + Codable，提供清晰错误信息
5. **Codegen 输出**: 现在生成 `+Types.swift` 扩展文件，包含所有 Params structs

### Android SDK 说明

Android SDK 现在使用与 iOS **相同的 Params 模式**：

- 使用 Gson 进行 JSON 反序列化
- `Function<ReturnType>("name") { ... }` - 无参数同步函数
- `Function<ParamsType, ReturnType>("name") { params -> ... }` - 有参数同步函数
- `AsyncFunction<ReturnType>("name") { ... }` - 无参数异步函数
- `AsyncFunction<ParamsType, ReturnType>("name") { params -> ... }` - 有参数异步函数
- 旧的 `FunctionN` API 已标记为 `@Deprecated`，保留向后兼容

### 待完成

🎉 **全部完成！** 强类型 Params 迁移已成功完成，iOS 和 Android 平台现在使用统一的 Params 模式。

---

## 目录

1. [背景与问题](#背景与问题)
2. [解决方案概述](#解决方案概述)
3. [设计决策](#设计决策)
4. [TypeScript 服务定义（输入）](#typescript-服务定义输入)
5. [Codegen 输出（iOS Swift）](#codegen-输出ios-swift)
6. [SDK 变更](#sdk-变更)
7. [Codegen 变更](#codegen-变更)
8. [文件生成策略](#文件生成策略)
9. [实现任务清单](#实现任务清单)
10. [测试计划](#测试计划)

---

## 背景与问题

### 当前实现的问题

当前的参数解析逻辑位于 `ServiceDefinition.swift` 的 `convertArgs` 函数中，存在以下问题：

```swift
// 当前: 多重 fallback 的 "猜测" 方式
private func convertArgs(_ args: [Any]) throws -> Args {
    // 1. 尝试直接类型匹配
    // 2. 尝试 ArgumentConverter
    // 3. 尝试从 dict 中提取单个值
    // 4. 尝试按 key 字母排序提取多值作为 tuple
    // ...
}
```

**问题列表**:

| 问题 | 描述 |
|------|------|
| 🔴 **依赖字母排序** | 多参数函数依赖 key 按字母顺序排序（a, b, c...），非常脆弱 |
| 🔴 **错误信息不明确** | 类型不匹配时只能报 "Cannot convert arguments" |
| 🔴 **隐式转换可能失败** | 多层 fallback 可能静默失败 |
| 🔴 **难以调试** | 不清楚哪一步转换失败 |
| 🔴 **代码冗余** | 三个地方有相同的 `convertArgs` 逻辑 |

---

## 解决方案概述

### 核心思路

用 Swift 的 `Codable` 协议替代手动参数解析：

```swift
// BEFORE (有问题)
Function("addTwo") { (a: Int, b: Int) -> Int in 
    a + b 
}

// AFTER (类型安全)
struct AddTwoParams: Codable { let a: Int; let b: Int }
Function("addTwo") { (params: AddTwoParams) -> Int in 
    params.a + params.b 
}
```

### 关键特性

1. **Params 通过 Codegen 自动生成** - 作为 Service 的 Extension
2. **返回值要求 Encodable** - 确保 JSON 序列化正确
3. **只有复杂类型才生成 Response struct** - 基础类型直接使用
4. **移除 Promise-style 函数** - 统一使用 async/await

---

## 设计决策

| 决策项 | 选择 | 原因 |
|--------|------|------|
| 返回类型约束 | ✅ 要求 `Encodable` | 类型安全，确保可序列化 |
| Promise-style 函数 | ❌ 移除 | async/await 更现代，减少复杂度 |
| 向后兼容 | ❌ 不保留 | 干净的破坏性变更，简化代码 |
| Params 位置 | Extension on Service | 符合 Swift 习惯，Codegen 友好 |
| Types 文件命名 | `{ClassName}+Types.swift` | 符合 Apple 扩展文件命名惯例 |
| Response 类型 | 用户显式定义 | 可控性强，避免生成冗余类型 |

---

## TypeScript 服务定义（输入）

```typescript
// codegen/examples/services.ts

// ============================================================================
// 共享类型定义
// ============================================================================

export interface CounterStats {
  incrementCount: number;
  decrementCount: number;
  peakValue: number;
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

// ============================================================================
// 服务定义
// ============================================================================

/**
 * Counter Service
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  // 无参数，基础类型返回
  getValue(): number;
  
  // 单参数，基础类型返回
  add(args: { value: number }): number;
  
  // 多参数，基础类型返回
  addTwo(args: { a: number; b: number }): number;
  
  // 无参数，复杂类型返回
  getStats(): CounterStats;
  
  // 有参数，复杂类型返回（异步）
  addAsync(args: { value: number; delayMs?: number }): Promise<CounterResult>;
  
  // 事件
  onCountChanged(): Event<{ count: number }>;
}
```

---

## Codegen 输出（iOS Swift）

### 文件结构

```
generated/swift/
├── CounterRPCService.swift         # 服务骨架（可编辑实现）
├── CounterRPCService+Types.swift   # Params 类型定义（自动生成）
└── SharedTypes.swift               # 共享类型定义（自动生成）
```

### 文件 1: `CounterRPCService+Types.swift`

> **⚠️ 完全自动生成，每次重新生成时覆盖**

```swift
//
// AUTO-GENERATED FILE - DO NOT MODIFY
// Generated by NativeRPC Code Generator
// Source: services.ts
// Generated at: 2024-01-XX
//

import Foundation

// MARK: - CounterRPCService Types

extension CounterRPCService {
    
    // MARK: - Request Params
    
    /// Params for `add` method
    struct AddParams: Codable {
        let value: Double
    }
    
    /// Params for `addTwo` method
    struct AddTwoParams: Codable {
        let a: Double
        let b: Double
    }
    
    /// Params for `addAsync` method
    struct AddAsyncParams: Codable {
        let value: Double
        let delayMs: Double?
    }
}
```

### 文件 2: `CounterRPCService.swift`

> **增量合并：保留 `{ }` 内的实现代码**

```swift
//
// AUTO-GENERATED FILE - DO NOT MODIFY THE STRUCTURE
// Generated by NativeRPC Code Generator
//
// IMPORTANT: Method implementations (the code inside { }) are preserved during regeneration.
//

import NativeRPCKit

final class CounterRPCService: NativeRPCService {
    
    // MARK: - Service Registration
    
    override class var serviceName: String { "counter" }
    
    // MARK: - Initialization
    
    required init(context: NativeRPCContext?) {
        super.init(context: context)
    }
    
    // MARK: - Service Definition
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        
        // 无参数 - 使用 () -> R
        Function("getValue") { () -> Double in
            // TODO: Implement getValue
            fatalError("Not implemented: getValue")
        }
        
        // 有参数 - 使用 (Params) -> R
        Function("add") { (params: AddParams) -> Double in
            // TODO: Implement add
            fatalError("Not implemented: add")
        }
        
        Function("addTwo") { (params: AddTwoParams) -> Double in
            // TODO: Implement addTwo
            fatalError("Not implemented: addTwo")
        }
        
        // 返回复杂类型
        Function("getStats") { () -> CounterStats in
            // TODO: Implement getStats
            fatalError("Not implemented: getStats")
        }
        
        // 异步 + 参数 + 复杂返回类型
        AsyncFunction("addAsync") { (params: AddAsyncParams) async throws -> CounterResult in
            // TODO: Implement addAsync
            fatalError("Not implemented: addAsync")
        }
        
        Events("countChanged")
    }
    
    // MARK: - Event Emitters
    
    func emitCountChanged(_ payload: [String: Any]) {
        emit("countChanged", data: payload)
    }
}
```

### 文件 3: `SharedTypes.swift`

> **⚠️ 完全自动生成，每次重新生成时覆盖**

```swift
//
// AUTO-GENERATED FILE - Shared Types
// Generated by NativeRPC Code Generator
//

import Foundation

/// Counter statistics
struct CounterStats: Codable {
    /// Total number of increments
    let incrementCount: Double
    /// Total number of decrements
    let decrementCount: Double
    /// Peak value reached
    let peakValue: Double
}

/// Counter operation result
struct CounterResult: Codable {
    /// The new counter value
    let value: Double
    /// Timestamp of the operation
    let timestamp: Double
    /// Operation that was performed
    let operation: CounterOperation
}

/// Types of counter operations
enum CounterOperation: String, Codable {
    case increment
    case decrement
    case add
    case reset
}
```

---

## SDK 变更

### 1. ServiceDefinition.swift

#### 新的类定义

```swift
/// Synchronous function definition with Codable params
public final class SyncFunctionDefinition<Params: Decodable, R: Encodable>: AnySyncFunction {
    public let name: String
    public let argumentsCount: Int
    private let body: (Params) throws -> R
    
    public init(name: String, argumentsCount: Int, body: @escaping (Params) throws -> R) {
        self.name = name
        self.argumentsCount = argumentsCount
        self.body = body
    }
    
    public func call(args: [Any]) throws -> Any? {
        let params: Params = try decodeParams(from: args)
        let result = try body(params)
        return try encodeResult(result)
    }
    
    private func decodeParams(from args: [Any]) throws -> Params {
        // Void 类型特殊处理
        if Params.self == Void.self {
            return () as! Params
        }
        
        // 从 args 中提取字典
        guard let dict = args.first as? [String: Any] else {
            throw NativeRPCError.invalidParams("Expected params dictionary, got: \(type(of: args.first))")
        }
        
        // 使用 JSONDecoder 解码
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Params.self, from: data)
        } catch let error as DecodingError {
            throw NativeRPCError.invalidParams(describeDecodingError(error))
        }
    }
    
    private func encodeResult(_ result: R) throws -> Any {
        // 基础类型直接返回
        if R.self == Int.self || R.self == Double.self || 
           R.self == String.self || R.self == Bool.self ||
           R.self == Void.self {
            return result
        }
        
        // 复杂类型编码为 JSON-compatible dictionary/array
        let data = try JSONEncoder().encode(result)
        return try JSONSerialization.jsonObject(with: data)
    }
    
    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required key: '\(key.stringValue)'"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Type mismatch at '\(path)': expected \(type)"
        case .valueNotFound(let type, let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return "Missing value at '\(path)': expected \(type)"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
```

#### AsyncFunctionDefinition（类似变更）

```swift
public final class AsyncFunctionDefinition<Params: Decodable, R: Encodable>: AnyAsyncFunction, @unchecked Sendable {
    // ... 同样的 decodeParams 和 encodeResult 逻辑
}
```

#### 移除内容

- ❌ `PromiseAsyncFunctionDefinition` 类
- ❌ `tupleFromArray()` 函数
- ❌ 所有 `convertArgs` 中的 fallback 逻辑

### 2. DSLFactories.swift

#### 保留的工厂函数（4个）

```swift
// MARK: - Sync Functions

/// 无参数版本
public func Function<R: Encodable>(
    _ name: String,
    _ body: @escaping () throws -> R
) -> SyncFunctionDefinition<Void, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 0) { _ in try body() }
}

/// Codable 参数版本
public func Function<Params: Decodable, R: Encodable>(
    _ name: String,
    _ body: @escaping (Params) throws -> R
) -> SyncFunctionDefinition<Params, R> {
    SyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}

// MARK: - Async Functions

/// 无参数版本
public func AsyncFunction<R: Encodable>(
    _ name: String,
    _ body: @escaping () async throws -> R
) -> AsyncFunctionDefinition<Void, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 0) { _ in try await body() }
}

/// Codable 参数版本
public func AsyncFunction<Params: Decodable, R: Encodable>(
    _ name: String,
    _ body: @escaping (Params) async throws -> R
) -> AsyncFunctionDefinition<Params, R> {
    AsyncFunctionDefinition(name: name, argumentsCount: 1, body: body)
}
```

#### 移除内容

- ❌ 所有 2-6 参数的 Function 重载
- ❌ 所有 2-6 参数的 AsyncFunction 重载
- ❌ 所有 Promise-style 的 AsyncFunction 重载

### 3. Promise.swift

**决策**: 删除整个文件

```
sdk/ios/Sources/NativeRPCKit/Core/Promise.swift -> DELETE
```

### 4. Convertible.swift

**决策**: 保留，用于特殊类型转换

保留 `ArgumentConverter` 用于：
- `Date` (ISO8601 string / timestamp)
- `URL` (string)
- `Data` (Base64 / byte array)
- `CGPoint`, `CGSize`, `CGRect` (dict / array)
- `UIColor` (hex string / dict)

这些仍然有用，可以在 Codable 之外提供额外的转换能力。

---

## Codegen 变更

### 1. Renderer 变更 (`src/renderer/index.ts`)

#### 新增 `methodNamePascal` 到 MethodView

```typescript
interface MethodView {
  methodName: string;
  methodNamePascal: string;  // NEW: "add" → "Add", "addTwo" → "AddTwo"
  hasParams: boolean;
  parameters: ParameterView[];
  returnType: string;
  // ... other fields
}

// 在 buildMethodView 中添加
protected buildMethodView(method: ServiceMethod, ...): MethodView {
  return {
    methodName: method.name,
    methodNamePascal: this.toPascalCase(method.name),  // NEW
    // ...
  };
}
```

#### 新增 Types Extension 渲染方法

```typescript
class SwiftRenderer extends ServiceRenderer {
  /**
   * 生成 Types extension 文件
   */
  renderTypesExtension(module: ServiceModule): string {
    return this.render(module, 'swift-params.mustache');
  }
  
  /**
   * 生成共享类型文件
   */
  renderSharedTypes(modules: ServiceModule[]): string {
    // 收集所有模块的 customTypes 和 enums
    const allCustomTypes = new Set<CustomType>();
    const allEnums = new Set<EnumType>();
    
    for (const module of modules) {
      module.customTypes.forEach(t => allCustomTypes.add(t));
      module.enums.forEach(e => allEnums.add(e));
    }
    
    return this.render({
      customTypes: Array.from(allCustomTypes),
      enums: Array.from(allEnums),
    }, 'swift-shared-types.mustache');
  }
}
```

### 2. 新增模板

#### `templates/swift/swift-params.mustache`

```mustache
//
// AUTO-GENERATED FILE - DO NOT MODIFY
// Generated by NativeRPC Code Generator
// Source: {{sourceFile}}
// Generated at: {{timestamp}}
//

import Foundation

{{#services}}
// MARK: - {{className}} Types

extension {{className}} {
    
    // MARK: - Request Params
    {{#allMethods}}
    {{#hasParams}}
    
    /// Params for `{{methodName}}` method
    struct {{methodNamePascal}}Params: Codable {
        {{#parameters}}
        let {{name}}: {{type}}{{#optional}}?{{/optional}}
        {{/parameters}}
    }
    {{/hasParams}}
    {{/allMethods}}
}
{{/services}}
```

#### `templates/swift/swift-shared-types.mustache`

```mustache
//
// AUTO-GENERATED FILE - Shared Types
// Generated by NativeRPC Code Generator
// Source: {{sourceFile}}
// Generated at: {{timestamp}}
//

import Foundation

{{#customTypes}}
{{#hasDocumentation}}
/// {{{documentation}}}
{{/hasDocumentation}}
struct {{name}}: Codable {
    {{#fields}}
    {{#documentation}}
    /// {{{documentation}}}
    {{/documentation}}
    let {{name}}: {{type}}{{#optional}}?{{/optional}}
    {{/fields}}
}

{{/customTypes}}
{{#enums}}
{{#hasDocumentation}}
/// {{{documentation}}}
{{/hasDocumentation}}
enum {{name}}: {{rawType}}, Codable {
    {{#members}}
    case {{swiftName}}{{#isString}} = "{{value}}"{{/isString}}
    {{/members}}
}

{{/enums}}
```

#### 更新 `templates/swift/service.mustache`

```mustache
{{#syncMethods}}
{{#hasDocumentation}}
// {{{documentation}}}
{{/hasDocumentation}}
Function("{{methodName}}") { {{#hasParams}}(params: {{methodNamePascal}}Params){{/hasParams}}{{^hasParams}}(){{/hasParams}} -> {{returnType}} in
    {{#existingImplementation}}
{{{.}}}
    {{/existingImplementation}}
    {{^existingImplementation}}
    // TODO: Implement {{methodName}}
    fatalError("Not implemented: {{methodName}}")
    {{/existingImplementation}}
}

{{/syncMethods}}
{{#asyncMethods}}
{{#hasDocumentation}}
// {{{documentation}}}
{{/hasDocumentation}}
AsyncFunction("{{methodName}}") { {{#hasParams}}(params: {{methodNamePascal}}Params){{/hasParams}}{{^hasParams}}(){{/hasParams}} async throws -> {{returnType}} in
    {{#existingImplementation}}
{{{.}}}
    {{/existingImplementation}}
    {{^existingImplementation}}
    // TODO: Implement {{methodName}}
    fatalError("Not implemented: {{methodName}}")
    {{/existingImplementation}}
}

{{/asyncMethods}}
```

### 3. 主生成器变更 (`src/index.ts`)

```typescript
class NativeRPCCodeGenerator {
  async generateSwift(module: ServiceModule, config: SwiftConfig): Promise<void> {
    const renderer = new SwiftRenderer(this.templateDir, config.serviceSuffix);
    
    // 1. 生成服务骨架（增量合并）
    const serviceCode = renderer.renderWithMerge(module, config.existingFilePath);
    await this.writeFile(`${config.outputDir}/${className}.swift`, serviceCode);
    
    // 2. 生成 Types extension（覆盖）
    const typesCode = renderer.renderTypesExtension(module);
    await this.writeFile(`${config.outputDir}/${className}+Types.swift`, typesCode);
  }
  
  async generateSharedTypes(modules: ServiceModule[], config: SwiftConfig): Promise<void> {
    const renderer = new SwiftRenderer(this.templateDir, config.serviceSuffix);
    const sharedCode = renderer.renderSharedTypes(modules);
    await this.writeFile(`${config.outputDir}/SharedTypes.swift`, sharedCode);
  }
}
```

---

## 文件生成策略

| 文件 | 内容 | 生成策略 | 用户可编辑 |
|------|------|---------|-----------|
| `{Service}.swift` | 服务骨架 + 方法实现 | **增量合并** | ✅ 可以编辑 `{ }` 内的代码 |
| `{Service}+Types.swift` | Params structs | **完全覆盖** | ❌ 不可编辑 |
| `SharedTypes.swift` | 共享类型 + 枚举 | **完全覆盖** | ❌ 不可编辑 |

---

## 实现任务清单

### Phase 1: SDK 重构 ⏱️ 预计 2-3 小时

| # | 任务 | 文件 | 优先级 |
|---|------|------|--------|
| 1.1 | 重构 `SyncFunctionDefinition` 使用 Codable | `ServiceDefinition.swift` | 🔴 高 |
| 1.2 | 重构 `AsyncFunctionDefinition` 使用 Codable | `ServiceDefinition.swift` | 🔴 高 |
| 1.3 | 移除 `PromiseAsyncFunctionDefinition` | `ServiceDefinition.swift` | 🔴 高 |
| 1.4 | 移除 `tupleFromArray()` 函数 | `ServiceDefinition.swift` | 🟡 中 |
| 1.5 | 简化 `DSLFactories.swift` 为 4 个函数 | `DSLFactories.swift` | 🔴 高 |
| 1.6 | 删除 `Promise.swift` | `Core/Promise.swift` | 🟡 中 |
| 1.7 | 更新现有测试 | `NativeRPCKitTests.swift` | 🔴 高 |
| 1.8 | 添加 Codable 解码错误测试 | `NativeRPCKitTests.swift` | 🟡 中 |

### Phase 2: Codegen 增强 ⏱️ 预计 2-3 小时

| # | 任务 | 文件 | 优先级 |
|---|------|------|--------|
| 2.1 | 添加 `methodNamePascal` 到 MethodView | `src/renderer/index.ts` | 🔴 高 |
| 2.2 | 添加 `allMethods` 视图（包含所有方法） | `src/renderer/index.ts` | 🟡 中 |
| 2.3 | 创建 `swift-params.mustache` 模板 | `templates/swift/` | 🔴 高 |
| 2.4 | 创建 `swift-shared-types.mustache` 模板 | `templates/swift/` | 🟡 中 |
| 2.5 | 更新 `service.mustache` 使用新语法 | `templates/swift/` | 🔴 高 |
| 2.6 | 添加 `renderTypesExtension` 方法 | `src/renderer/index.ts` | 🔴 高 |
| 2.7 | 更新主生成器生成多文件 | `src/index.ts` | 🔴 高 |

### Phase 3: 示例更新 ⏱️ 预计 1 小时

| # | 任务 | 文件 | 优先级 |
|---|------|------|--------|
| 3.1 | 更新 CounterService 使用 Params 模式 | `CounterService.swift` | 🔴 高 |
| 3.2 | 移除 Promise-style 方法 | `CounterService.swift` | 🟡 中 |
| 3.3 | 添加 Params structs | `CounterService.swift` 或生成 | 🔴 高 |

### Phase 4: 集成测试 ⏱️ 预计 1 小时

| # | 任务 | 命令/文件 | 优先级 |
|---|------|----------|--------|
| 4.1 | 运行 iOS SDK 测试 | `cd sdk/ios && swift test` | 🔴 高 |
| 4.2 | 运行 Codegen | `npm run generate -- generate --config examples/config.json --swift` | 🔴 高 |
| 4.3 | 测试 Web Demo → WebView | 手动测试 | 🔴 高 |
| 4.4 | 验证错误消息 | 发送错误参数测试 | 🟡 中 |

---

## 测试计划

### 单元测试

```swift
// 1. 基本 Codable 解码
func testCodableParamDecoding() async throws {
    struct AddParams: Codable { let value: Int }
    
    class TestService: NativeRPCService {
        override class var serviceName: String { "test" }
        
        @ServiceDefinitionBuilder
        override func definition() -> ServiceDefinitionContainer {
            Function("add") { (params: AddParams) -> Int in
                params.value * 2
            }
        }
    }
    
    let service = TestService()
    
    // 传入字典参数
    let result = try await service.handleCall(method: "add", args: [["value": 5]])
    XCTAssertEqual(result as? Int, 10)
}

// 2. 解码错误 - 缺少必需字段
func testMissingRequiredField() async {
    struct Params: Codable { let a: Int; let b: Int }
    
    // ... 省略服务定义
    
    do {
        _ = try await service.handleCall(method: "add", args: [["a": 1]])  // 缺少 b
        XCTFail("Should throw")
    } catch let error as NativeRPCError {
        XCTAssertTrue(error.message.contains("Missing required key: 'b'"))
    }
}

// 3. 解码错误 - 类型不匹配
func testTypeMismatch() async {
    struct Params: Codable { let value: Int }
    
    // ... 省略服务定义
    
    do {
        _ = try await service.handleCall(method: "add", args: [["value": "not a number"]])
        XCTFail("Should throw")
    } catch let error as NativeRPCError {
        XCTAssertTrue(error.message.contains("Type mismatch"))
    }
}

// 4. 可选参数
func testOptionalParam() async throws {
    struct Params: Codable { 
        let required: Int
        let optional: Int?
    }
    
    // ... 省略服务定义
    
    // 不传 optional
    let result1 = try await service.handleCall(method: "test", args: [["required": 1]])
    XCTAssertEqual(result1 as? Int, 1)
    
    // 传 optional
    let result2 = try await service.handleCall(method: "test", args: [["required": 1, "optional": 2]])
    XCTAssertEqual(result2 as? Int, 3)
}

// 5. 复杂返回类型
func testComplexReturnType() async throws {
    struct Result: Codable, Equatable { 
        let value: Int
        let name: String 
    }
    
    // ... 省略服务定义
    
    let result = try await service.handleCall(method: "getResult", args: [])
    guard let dict = result as? [String: Any] else {
        XCTFail("Expected dictionary")
        return
    }
    
    XCTAssertEqual(dict["value"] as? Int, 42)
    XCTAssertEqual(dict["name"] as? String, "test")
}
```

### 端到端测试

```bash
# 1. 启动 Web Demo
cd examples/web-counter
pnpm dev

# 2. 在 iOS 模拟器中运行 Flutter 应用
cd connections/flutter/native_rpc_flutter/example
flutter run

# 3. 打开 WebView，测试以下场景:
# - 点击 Increment/Decrement (无参数)
# - 点击 Add 5 (单参数)
# - 点击 AddTwo(3, 7) (多参数)
# - 验证错误处理（在控制台发送错误请求）
```

---

## 迁移指南

### 用户代码迁移

#### Before (当前 API)

```swift
class CounterService: NativeRPCService {
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // 单参数 - tuple style
        Function("add") { (value: Int) -> Int in
            self.count += value
            return self.count
        }
        
        // 多参数 - tuple style
        Function("addTwo") { (a: Int, b: Int) -> Int in
            self.count += a + b
            return self.count
        }
        
        // Promise style (被移除)
        AsyncFunction("fetchData") { (id: String, promise: Promise) in
            api.fetch(id) { result in
                promise.resolve(result)
            }
        }
    }
}
```

#### After (新 API)

```swift
class CounterService: NativeRPCService {
    
    // Params 定义（可以放在 extension 中，或由 codegen 生成）
    struct AddParams: Codable { let value: Int }
    struct AddTwoParams: Codable { let a: Int; let b: Int }
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        // 单参数 - Codable style
        Function("add") { (params: AddParams) -> Int in
            self.count += params.value
            return self.count
        }
        
        // 多参数 - Codable style
        Function("addTwo") { (params: AddTwoParams) -> Int in
            self.count += params.a + params.b
            return self.count
        }
        
        // 使用 async/await 替代 Promise
        AsyncFunction("fetchData") { (params: FetchDataParams) async throws -> Data in
            return try await api.fetch(params.id)
        }
    }
}
```

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 破坏性 API 变更 | 现有用户代码需要修改 | 提供清晰的迁移指南 |
| Codable 解码性能 | 可能比直接转换慢 | 实际测试表明差异可忽略 |
| 移除 Promise-style | 某些 callback API 难以桥接 | 用户可用 `withCheckedContinuation` 包装 |

---

## 附录

### 相关文件位置

| 用途 | 文件路径 |
|------|----------|
| ServiceDefinition | `sdk/ios/Sources/NativeRPCKit/DSL/ServiceDefinition.swift` |
| DSLFactories | `sdk/ios/Sources/NativeRPCKit/DSL/DSLFactories.swift` |
| Promise | `sdk/ios/Sources/NativeRPCKit/Core/Promise.swift` |
| Convertible | `sdk/ios/Sources/NativeRPCKit/Core/Convertible.swift` |
| 测试 | `sdk/ios/Tests/NativeRPCKitTests/NativeRPCKitTests.swift` |
| CounterService | `connections/flutter/native_rpc_flutter/example/ios/Runner/CounterService.swift` |
| Swift Template | `codegen/templates/swift/service.mustache` |
| Renderer | `codegen/src/renderer/index.ts` |
| 服务定义 (TS) | `codegen/examples/services.ts` |

### 命令参考

```bash
# 运行 iOS SDK 测试
cd sdk/ios && swift test

# 运行 Codegen
cd codegen && npm run generate -- generate --config examples/config.json --swift

# 启动 Web Demo
cd examples/web-counter && pnpm dev

# 运行 Flutter 应用
cd connections/flutter/native_rpc_flutter/example && flutter run
```
