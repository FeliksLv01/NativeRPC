# NativeRPC 代码生成器

从 TypeScript 服务定义生成类型安全的客户端和服务端存根。

## 特性

- **TypeScript 优先**: 使用 TypeScript 接口定义服务 - 比 YAML/JSON 更直观
- **多平台输出**: 生成 Dart、TypeScript (Web)、Swift 和 Kotlin 代码
- **增量更新**: Swift/Kotlin 生成器保留您的方法实现
- **类型安全**: 生成的客户端具有正确的参数和返回类型
- **事件支持**: 一流的事件订阅支持
- **可配置命名**: 自定义服务类名、文件名和包名

## 安装

```bash
npm install nativerpc-codegen
# 或
yarn add nativerpc-codegen
```

## 快速开始

### 1. 定义您的服务

创建一个包含服务定义的 TypeScript 文件:

```typescript
// services.ts

/**
 * 计数器统计信息
 */
export interface CounterStats {
  incrementCount: number;
  decrementCount: number;
  peakValue: number;
}

/**
 * 计数器服务
 * @service
 * @serviceName counter
 */
export interface ICounterService {
  // 同步方法（直接返回值）
  getValue(): number;
  
  // 带参数的方法
  add(args: { value: number }): number;
  
  // 异步方法（返回 Promise）
  getValueDelayed(args: { delayMs: number }): Promise<number>;
  
  // 事件（返回 Event<PayloadType>）
  onCountChanged(): Event<{ oldValue: number; newValue: number }>;
}

// 事件类型标记
export type Event<T> = { __eventPayload: T };
```

### 2. 创建配置

创建 `nativerpc.config.json`:

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

### 3. 生成代码

```bash
npx nativerpc-codegen generate --config nativerpc.config.json

# 预览运行（不写入文件）
npx nativerpc-codegen generate --config nativerpc.config.json --dry-run
```

## 生成输出

使用 `serviceSuffix: "RPCService"` 时，生成器产生:

| 语言 | 文件名 | 类名 |
|----------|-----------|------------|
| Swift | `CounterRPCService.swift` | `CounterRPCService` |
| Kotlin | `CounterRPCService.kt` | `CounterRPCService` |
| Dart | `counter_rpc_service.dart` | `CounterRPCService` |
| TypeScript | `counter-rpc-service.ts` | `CounterRPCService` |

### Dart (Flutter 客户端)

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

### Swift (服务端存根)

```swift
final class CounterRPCService: NativeRPCService {
    override var definition: ServiceDefinition {
        Service("counter") {
            Function("getValue") { () -> Int in
                // 在此实现
            }
            
            Function("add") { (value: Int) -> Int in
                // 在此实现
            }
            
            AsyncFunction("getValueDelayed") { (delayMs: Int) async throws -> Int in
                // 在此实现
            }
            
            Event("countChanged")
        }
    }
    
    func emitCountChanged(_ payload: CountChangedPayload) {
        emit("countChanged", data: payload)
    }
}
```

### Kotlin (服务端存根)

```kotlin
package com.itoken.team

class CounterRPCService : NativeRPCService("counter") {
    override fun definition() = service {
        function("getValue") { ->
            // 在此实现
        }
        
        function("add") { value: Int ->
            // 在此实现
        }
        
        suspendFunction("getValueDelayed") { delayMs: Int ->
            // 在此实现
        }
        
        event("countChanged")
    }
    
    fun emitCountChanged(payload: CountChangedPayload) {
        emit("countChanged", payload)
    }
}
```

## 方法类型

生成器从返回类型推断方法类型:

| TypeScript 返回类型 | 方法类型 | 生成代码 |
|------------------------|-------------|----------------|
| `T` (任何非 Promise) | 同步 | `Function` / `function` |
| `Promise<T>` | 异步 | `AsyncFunction` / `suspendFunction` |
| `void` | 无返回值 | `Function`（无返回） |
| `Event<T>` | 事件 | `Event` 定义 + emit 辅助方法 |

## 增量更新

重新生成 Swift/Kotlin 代码时，生成器会:

1. 解析现有文件以提取方法实现
2. 生成带有更新方法签名的新代码
3. **保留**所有 `{ }` 内的现有实现代码
4. 为新方法添加 TODO 占位符
5. 报告已删除的方法（其实现将丢失）

### 示例输出

```
=== 方法差异报告 ===

➕ 新增方法:
   + newMethod

➖ 删除方法（实现将丢失）:
   - deprecatedMethod

✓ 5 个方法未变更
```

## 配置参考

### `parsing`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `sources` | `string[]` | 必填 | TypeScript 源文件的 glob 模式 |
| `tsconfigPath` | `string` | - | tsconfig.json 路径 |
| `dropInterfaceIPrefix` | `boolean` | `false` | 移除接口名的 'I' 前缀 |
| `predefinedTypes` | `string[]` | - | 不解析的类型（如 `["Date", "URL"]`）|

### `rendering`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `serviceSuffix` | `string` | `"RPCService"` | 生成的服务类名后缀 |

### `rendering.dart`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `outputPath` | `string` | 必填 | 输出目录 |
| `packageName` | `string` | - | 导入包名 |
| `templatePath` | `string` | - | 自定义模板路径 |

### `rendering.typescript`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `outputPath` | `string` | 必填 | 输出目录 |
| `useESModules` | `boolean` | `false` | 使用 ES 模块语法 |
| `templatePath` | `string` | - | 自定义模板路径 |

### `rendering.swift`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `outputPath` | `string` | 必填 | 输出目录 |
| `existingServicePath` | `string` | - | 现有服务路径，用于增量合并 |
| `imports` | `string[]` | - | 要包含的 import 语句 |
| `baseClass` | `string` | - | 服务的基类 |
| `templatePath` | `string` | - | 自定义模板路径 |

### `rendering.kotlin`

| 选项 | 类型 | 默认值 | 描述 |
|--------|------|---------|-------------|
| `outputPath` | `string` | 必填 | 输出目录 |
| `existingServicePath` | `string` | - | 现有服务路径，用于增量合并 |
| `packageName` | `string` | `"com.itoken.team"` | Kotlin 包名 |
| `imports` | `string[]` | - | 要包含的 import 语句 |
| `baseClass` | `string` | - | 服务的基类 |
| `templatePath` | `string` | - | 自定义模板路径 |

## 自定义模板

您可以提供自定义 Mustache 模板:

```json
{
  "rendering": {
    "swift": {
      "templatePath": "./my-templates/swift-service.mustache"
    }
  }
}
```

参见 `templates/` 目录获取内置模板。

## CLI 命令

```bash
# 生成所有平台
nativerpc-codegen generate --config config.json

# 预览运行（不写入文件）
nativerpc-codegen generate --config config.json --dry-run

# 仅生成特定平台
nativerpc-codegen generate --config config.json --swift --kotlin

# 初始化新配置文件
nativerpc-codegen init

# 显示差异报告（将会变更的内容）
nativerpc-codegen diff --config config.json
```

## 许可证

MIT
