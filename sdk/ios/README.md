# NativeRPC

NativeRPC 是一个 **协议优先的 Swift RPC 框架**，提供声明式的 Swift DSL 以及可插拔的连接层。它使用简化的 JSON-RPC 2.0 协议进行通信，支持多种传输方式。

## 主要特性

- **协议优先设计**：基于简化的 JSON-RPC 2.0 协议
- **可插拔连接**：支持 WebSocket、HTTP 或实现自定义传输
- **声明式 DSL**：受 Expo Modules 启发的 Swift API
- **类型安全代码生成**：从 TypeScript 接口生成 Swift 客户端
- **单通道设计**：每个主机的所有 RPC 调用共享一个连接
- **Swift Concurrency 支持**：原生 async/await 支持

## 安装

或通过 Xcode 添加：File → Add Package Dependencies → 输入仓库 URL。

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'NativeRPCKit', :git => 'https://github.com/FeliksLv01/NativeRPC.git'
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

### 定义服务

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
        
        Function("add") { (a: Int, b: Int) -> Int in
            a + b
        }
        
        Events("countChanged")
    }
}
```

### 创建主机和连接

```swift
import NativeRPCKit

let host = NativeRPCHost()
host.register(CounterService())

let connection = WebSocketConnection(url: URL(string: "wss://example.com/rpc")!)
host.addConnection(connection)
```

### 客户端调用

```swift
import NativeRPCKit

let client = NativeRPCClient(connection: connection)

let value = try await client.call("counter.increment", params: nil)
print('新计数: \(value)')

let sum = try await client.call("math.add", params: ["a": 1, "b": 2])

client.on("counter.countChanged") { data in
    print('计数已更改: \(data["count"])')
}
```

### 自定义连接

```swift
import NativeRPCKit

class MyWebSocketConnection: NativeRPCConnection {
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func send(_ message: String) async throws {
        // 通过 WebSocket 发送 JSON 消息
    }
    
    func setOnMessage(_ handler: @escaping (String) -> Void) {
        // 设置消息接收处理
    }
}
```

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

## 设计原则

1. **协议优先**：消息格式是与语言无关的 JSON（简化的 JSON-RPC 2.0）
2. **纯 Swift 实现**：无其他语言依赖
3. **可插拔连接**：连接层被抽象化（WebSocket、HTTP 等）
4. **单通道**：每个主机的所有 RPC 调用共享一个连接
5. **类型安全**：生成器从 TypeScript 接口生成类型安全的代码
6. **声明式 DSL**：使用简单、可读的语法定义服务
7. **Swift Concurrency**：原生支持 async/await 和 Sendable

## 许可证

MIT
