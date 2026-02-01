# NativeRPC

NativeRPC 是一个 **协议优先的 RPC 框架**，为 iOS 和 Android 提供独立的原生 SDK，以及可插拔的连接层。它具有声明式的、Expo Modules 风格的 Swift 和 Kotlin DSL，并提供使用 MethodChannel 进行传输的 Flutter 集成。

## 主要特性

- **协议优先设计**：NativeRPC 是一个统一的协议，不仅仅是 Flutter 插件
- **独立 SDK**：iOS 和 Android SDK 可独立工作，无需 Flutter
- **可插拔连接**：使用 MethodChannel、WebSocket、HTTP 或实现自定义传输
- **声明式 DSL**：为 Swift 和 Kotlin 服务提供受 Expo Modules 启发的 API
- **类型安全代码生成**：从 TypeScript 接口生成 Dart/Swift/Kotlin 客户端
- **单通道设计**：每个主机的所有 RPC 调用共享一个连接

## 安装

### iOS (Swift Package Manager)

在 `Package.swift` 中添加以下内容或使用 Xcode 的"添加包依赖"：

```swift
dependencies: [
    .package(url: "https://github.com/FeliksLv01/NativeRPC.git", from: "1.0.0")
]
```

或通过 Xcode 添加：File → Add Package Dependencies → 输入仓库 URL。

### iOS (CocoaPods)

在 `Podfile` 中添加：

```ruby
pod 'NativeRPCKit', :git => 'https://github.com/FeliksLv01/NativeRPC.git'
```

### Android (Gradle)

在 `build.gradle.kts` 中添加：

```kotlin
dependencies {
    implementation("com.itoken.team:nativerpc:1.0.0")
}
```

### Flutter

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  native_rpc_flutter:
    git:
      url: https://github.com/FeliksLv01/NativeRPC.git
      path: connections/flutter/native_rpc_flutter
```

## 协议

NativeRPC 使用 **简化的 JSON-RPC 2.0** 协议（不带 `jsonrpc` 字段）。

### 请求（方法调用）

```json
{
  "id": "1",
  "method": "counter.increment",
  "params": {"step": 1}
}
```

### 响应（成功）

```json
{
  "id": "1",
  "result": 42
}
```

### 响应（错误）

```json
{
  "id": "1",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": {}
  }
}
```

### 通知（事件，无 id）

```json
{
  "method": "counter.countChanged",
  "params": {"count": 42}
}
```

## 使用示例

### Flutter 与 MethodChannel

**Dart (Flutter 应用)：**

```dart
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

// 调用方法（首次使用时自动初始化）
final value = await NativeRPC.call<int>('counter.increment');
print('新计数: $value');

// 带参数
final sum = await NativeRPC.call<int>('math.add', {'a': 1, 'b': 2});

// 监听事件
NativeRPC.on('counter.countChanged', (data) {
  print('计数已更改: ${data["count"]}');
});

// 移除监听器
NativeRPC.off('counter.countChanged', myHandler);
```

**Swift (iOS)：**

```swift
import NativeRPCKit

class CounterService: NativeRPCService {
    private var count = 0

    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("counter")
        
        Function("increment") { [weak self] () -> Int in
            guard let self else { return 0 }
            self.count += 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Events("countChanged")
    }
}

// 在 AppDelegate.swift 中
let host = NativeRPCHost()
host.register(CounterService())

let connection = FlutterMethodChannelConnection(channelName: "native_rpc")
host.addConnection(connection)
```

**Kotlin (Android)：**

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.dsl.*

class CounterService : NativeRPCService() {
    private var count = 0

    override fun definition() = serviceDefinition {
        Name("counter")
        
        Function0<Int>("increment") {
            count++
            emit("countChanged", mapOf("count" to count))
            count
        }
        
        Events("countChanged")
    }
}

// 在 MainActivity.kt 中
val host = NativeRPCHost()
host.register(CounterService())

val connection = FlutterMethodChannelConnection(channelName = "native_rpc")
host.addConnection(connection)
```

### 独立 iOS SDK（无 Flutter）

```swift
import NativeRPCKit

// 创建自定义连接（例如 WebSocket）
class MyWebSocketConnection: NativeRPCConnection {
    func send(_ message: String) {
        // 通过 WebSocket 发送 JSON 消息
    }
    
    // 接收数据时调用 onMessage()
}

let host = NativeRPCHost()
host.register(CounterService())

let connection = MyWebSocketConnection()
host.addConnection(connection)
```

### 独立 Android SDK（无 Flutter）

```kotlin
import com.itoken.team.nativerpc.core.*
import com.itoken.team.nativerpc.connection.*

// 创建自定义连接
class MyWebSocketConnection : NativeRPCConnection() {
    override fun send(message: String) {
        // 通过 WebSocket 发送 JSON 消息
    }
    
    // 接收数据时调用 onMessage()
}

val host = NativeRPCHost()
host.register(CounterService())

val connection = MyWebSocketConnection()
host.addConnection(connection)
```

## 代码生成

从 TypeScript 接口生成类型安全的客户端：

```bash
cd codegen
npm install
npm run generate -- generate --config examples/config.json
```

详情请参阅 [codegen/README.md](codegen/README.md)。

## 错误码（JSON-RPC 2.0 标准）

| 代码 | 名称 | 描述 |
|------|------|------|
| -32700 | Parse error | 无效的 JSON |
| -32600 | Invalid Request | 无效的请求对象 |
| -32601 | Method not found | 方法不存在 |
| -32602 | Invalid params | 无效的参数 |
| -32603 | Internal error | 内部错误 |
| -32001 | Service not found | 服务不存在 |
| -32002 | Event not found | 事件不存在 |
| -32003 | Timeout | 请求超时 |
| -32004 | Connection error | 连接失败 |

## 项目结构

```
NativeRPC/
├── sdk/                             # 独立的原生 SDK
│   ├── ios/                        # Swift SDK (NativeRPCKit)
│   └── android/                    # Kotlin SDK
│
├── connections/                     # 连接层实现
│   └── flutter/
│       └── native_rpc_flutter/     # Flutter 插件
│
├── codegen/                         # TypeScript 代码生成器
│   ├── src/                        # 生成器源代码
│   ├── templates/                  # Mustache 模板
│   └── examples/                   # 示例配置
│
├── examples/
│   └── flutter_counter/            # Flutter 示例应用
│
├── docs/                            # 文档
├── Package.swift                    # SPM 包（根目录）
└── NativeRPCKit.podspec            # CocoaPods 规范（根目录）
```

## 设计原则

1. **协议优先**：消息格式是与语言无关的 JSON（简化的 JSON-RPC 2.0）
2. **SDK 隔离**：iOS 和 Android SDK 零 Flutter 依赖
3. **可插拔连接**：连接层被抽象化（MethodChannel、WebSocket 等）
4. **单通道**：每个主机的所有 RPC 调用共享一个连接/通道
5. **类型安全**：生成器从 TypeScript 接口生成类型安全的代码
6. **声明式 DSL**：使用简单、可读的语法定义服务

## 许可证

MIT
