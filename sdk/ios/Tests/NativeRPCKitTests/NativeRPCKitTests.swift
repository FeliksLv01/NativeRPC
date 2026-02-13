// NativeRPCKitTests.swift
// NativeRPCKit v2
//
// Unit tests for NativeRPCKit

import XCTest
@testable import NativeRPCKit

// MARK: - Test Parameter Types

struct AddParams: Codable {
    let a: Int
    let b: Int
}

struct GreetParams: Codable {
    let name: String
}

struct ValueParams: Codable {
    let value: Int
}

struct DelayParams: Codable {
    let ms: Int
}

struct FetchParams: Codable {
    let id: String
}

struct FetchResult: Codable {
    let id: String
    let name: String
}

struct DateParams: Codable {
    let date: String
}

final class NativeRPCKitTests: XCTestCase {
    
    // MARK: - Service Definition Tests
    
    func testServiceDefinitionDSL() {
        // Create a test service
        class TestService: NativeRPCService {
            override class var serviceName: String { "test" }
            
            var addCallCount = 0
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                // Name() is no longer needed - serviceName is used automatically
                
                Function("add") { [weak self] (params: AddParams) -> Int in
                    self?.addCallCount += 1
                    return params.a + params.b
                }
                
                Function("greet") { (params: GreetParams) -> String in
                    "Hello, \(params.name)!"
                }
                
                Events("dataChanged", "statusUpdated")
            }
        }
        
        let service = TestService()
        
        // Test service name
        XCTAssertEqual(service.name, "test")
        
        // Test method discovery
        XCTAssertTrue(service.canHandle(method: "add"))
        XCTAssertTrue(service.canHandle(method: "greet"))
        XCTAssertFalse(service.canHandle(method: "unknown"))
        
        // Test events
        XCTAssertTrue(service.definitionContainer.hasEvent("dataChanged"))
        XCTAssertTrue(service.definitionContainer.hasEvent("statusUpdated"))
        XCTAssertFalse(service.definitionContainer.hasEvent("unknown"))
    }
    
    func testSyncFunctionCall() async throws {
        class MathService: NativeRPCService {
            override class var serviceName: String { "math" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("add") { (params: AddParams) -> Int in
                    params.a + params.b
                }
                
                Function("getValue") { () -> Int in
                    42
                }
            }
        }
        
        let service = MathService()
        
        // Test add with params dictionary
        let addResult = try await service.handleCall(method: "add", args: [["a": 5, "b": 3]])
        XCTAssertEqual(addResult as? Int, 8)
        
        // Test no-params function
        let valueResult = try await service.handleCall(method: "getValue", args: [])
        XCTAssertEqual(valueResult as? Int, 42)
    }
    
    func testAsyncFunctionCall() async throws {
        class AsyncService: NativeRPCService {
            override class var serviceName: String { "async" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("delay") { (params: DelayParams) async -> String in
                    try? await Task.sleep(nanoseconds: UInt64(params.ms) * 1_000_000)
                    return "done after \(params.ms)ms"
                }
                
                AsyncFunction("noParams") { () async -> String in
                    return "no params needed"
                }
            }
        }
        
        let service = AsyncService()
        
        let result = try await service.handleCall(method: "delay", args: [["ms": 10]])
        XCTAssertEqual(result as? String, "done after 10ms")
        
        let noParamsResult = try await service.handleCall(method: "noParams", args: [])
        XCTAssertEqual(noParamsResult as? String, "no params needed")
    }
    
    func testVoidReturnFunction() async throws {
        class VoidService: NativeRPCService {
            override class var serviceName: String { "void" }
            
            var lastValue: Int = 0
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("setValue") { [weak self] (params: ValueParams) in
                    self?.lastValue = params.value
                }
                
                Function("reset") { [weak self] () in
                    self?.lastValue = 0
                }
            }
        }
        
        let service = VoidService()
        
        // Test void function with params
        _ = try await service.handleCall(method: "setValue", args: [["value": 42]])
        XCTAssertEqual(service.lastValue, 42)
        
        // Test void function without params
        _ = try await service.handleCall(method: "reset", args: [])
        XCTAssertEqual(service.lastValue, 0)
    }
    
    // MARK: - Codable Decoding Error Tests
    
    func testMissingRequiredKey() async {
        class ParamService: NativeRPCService {
            override class var serviceName: String { "param" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("add") { (params: AddParams) -> Int in
                    params.a + params.b
                }
            }
        }
        
        let service = ParamService()
        
        // Missing key 'b'
        do {
            _ = try await service.handleCall(method: "add", args: [["a": 5]])
            XCTFail("Should have thrown an error")
        } catch let error as NativeRPCError {
            XCTAssertEqual(error.code, NativeRPCErrorCode.invalidParams)
            XCTAssertTrue(error.message.contains("b"), "Error should mention missing key 'b'")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testTypeMismatch() async {
        class ParamService: NativeRPCService {
            override class var serviceName: String { "param" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("add") { (params: AddParams) -> Int in
                    params.a + params.b
                }
            }
        }
        
        let service = ParamService()
        
        // Wrong type for 'a' (string instead of int)
        do {
            _ = try await service.handleCall(method: "add", args: [["a": "five", "b": 3]])
            XCTFail("Should have thrown an error")
        } catch let error as NativeRPCError {
            XCTAssertEqual(error.code, NativeRPCErrorCode.invalidParams)
            XCTAssertTrue(error.message.contains("Type mismatch"), "Error should mention type mismatch")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testInvalidParamsFormat() async {
        class ParamService: NativeRPCService {
            override class var serviceName: String { "param" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("add") { (params: AddParams) -> Int in
                    params.a + params.b
                }
            }
        }
        
        let service = ParamService()
        
        // Pass non-dictionary (array or primitive) when dictionary expected
        do {
            _ = try await service.handleCall(method: "add", args: [5, 3])
            XCTFail("Should have thrown an error")
        } catch let error as NativeRPCError {
            XCTAssertEqual(error.code, NativeRPCErrorCode.invalidParams)
            XCTAssertTrue(error.message.contains("Expected params dictionary"), "Error should mention expected format")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Service Center Tests
    
    func testServiceCenterRegistration() {
        class AppService: NativeRPCService, @unchecked Sendable {
            override class var serviceName: String { "app" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                // Empty definition - serviceName is used automatically
            }
        }
        
        // Register service type
        NativeRPCServiceCenter.shared.register(AppService.self)
        
        // Check registration
        let names = NativeRPCServiceCenter.shared.getRegisteredServiceNames()
        XCTAssertTrue(names.contains("app"))
        
        // Clean up
        NativeRPCServiceCenter.shared.unregister(name: "app")
    }
    
    // MARK: - Connection Tests
    
    func testCallbackConnection() {
        var sentStrings: [String] = []
        
        let connection = CallbackConnection(connectionType: .custom) { jsonString in
            sentStrings.append(jsonString)
        }
        
        XCTAssertTrue(connection.isActive)
        
        let testMessage = "test message"
        connection.send(testMessage)
        
        XCTAssertEqual(sentStrings.count, 1)
        XCTAssertEqual(sentStrings.first, testMessage)
        
        connection.close()
        XCTAssertFalse(connection.isActive)
    }
    
    func testInMemoryConnectionPair() {
        // In the new architecture, InMemoryConnectionPair connects two connections
        // Messages are routed through stubs, not through simple callbacks
        let pair = InMemoryConnectionPair()
        
        XCTAssertTrue(pair.client.isActive)
        XCTAssertTrue(pair.server.isActive)
        
        // Test close
        pair.close()
        XCTAssertFalse(pair.client.isActive)
        XCTAssertFalse(pair.server.isActive)
    }
    
    // MARK: - Message Encoding/Decoding Tests
    
    func testRequestParsing() throws {
        let json = """
        {"id": "test-123", "method": "math.add", "params": {"a": 1, "b": 2}}
        """.data(using: .utf8)!
        
        let message = try NativeRPCMessageParser.parse(json)
        
        if case .call(let request) = message {
            XCTAssertEqual(request.id, "test-123")
            XCTAssertEqual(request.method, "math.add")
            XCTAssertEqual(request.service, "math")
            XCTAssertEqual(request.methodName, "add")
        } else {
            XCTFail("Expected call message")
        }
    }
    
    func testResponseEncoding() throws {
        let response = NativeRPCResponse(id: "test-123", result: 42)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["id"] as? String, "test-123")
        XCTAssertEqual(json?["result"] as? Int, 42)
    }
    
    func testNotificationEncoding() throws {
        let notification = NativeRPCNotification(
            service: "user",
            event: "userChanged",
            params: ["id": "123", "name": "John"]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(notification)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(json?["method"] as? String, "user.userChanged")
        let params = json?["params"] as? [String: Any]
        XCTAssertEqual(params?["id"] as? String, "123")
        XCTAssertEqual(params?["name"] as? String, "John")
    }
    
    // MARK: - Async Function Tests (Replacing Promise Tests)
    
    func testAsyncFunctionWithResult() async throws {
        class FetchService: NativeRPCService {
            override class var serviceName: String { "fetch" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("fetchData") { (params: FetchParams) async throws -> FetchResult in
                    // Simulate async work
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    return FetchResult(id: params.id, name: "Test User")
                }
            }
        }
        
        let service = FetchService()
        let result = try await service.handleCall(method: "fetchData", args: [["id": "123"]])
        
        guard let dict = result as? [String: Any] else {
            XCTFail("Expected dictionary result")
            return
        }
        
        XCTAssertEqual(dict["id"] as? String, "123")
        XCTAssertEqual(dict["name"] as? String, "Test User")
    }
    
    func testAsyncFunctionWithError() async {
        class FailingService: NativeRPCService {
            override class var serviceName: String { "failing" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("failingOp") { () async throws -> Int in
                    throw NativeRPCError(code: -1, message: "Operation failed")
                }
            }
        }
        
        let service = FailingService()
        
        do {
            _ = try await service.handleCall(method: "failingOp", args: [])
            XCTFail("Should have thrown an error")
        } catch let error as NativeRPCError {
            XCTAssertEqual(error.code, -1)
            XCTAssertEqual(error.message, "Operation failed")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Queue Execution Tests
    
    func testRunOnQueue() async throws {
        class QueueService: NativeRPCService {
            override class var serviceName: String { "queue" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("work") { () async -> String in
                    return "done"
                }.runOnQueue(DispatchQueue.global())
            }
        }
        
        let service = QueueService()
        let result = try await service.handleCall(method: "work", args: [])
        XCTAssertEqual(result as? String, "done")
    }

    func testRunOnMain() async throws {
        class MainActorService: NativeRPCService {
            override class var serviceName: String { "main" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("work") { () async -> String in
                    // Just verify it runs without crashing
                    return "main thread work"
                }.runOnMain()
            }
        }
        
        let service = MainActorService()
        let result = try await service.handleCall(method: "work", args: [])
        XCTAssertEqual(result as? String, "main thread work")
    }
    
    func testSyncFunctionRunsOnMainByDefault() async throws {
        class UIService: NativeRPCService, @unchecked Sendable {
            override class var serviceName: String { "ui" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                // Sync functions run on main thread by default
                Function("checkThread") { () -> Bool in
                    Thread.isMainThread
                }
            }
        }
        
        let service = UIService()
        // Call from a background task to verify it switches to main
        let result = try await Task.detached {
            try await service.handleCall(method: "checkThread", args: [])
        }.value
        XCTAssertEqual(result as? Bool, true, "Sync function should run on main thread by default")
    }
    
    func testSyncFunctionRunInBackground() async throws {
        class BackgroundService: NativeRPCService, @unchecked Sendable {
            override class var serviceName: String { "background" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                // Explicitly run on background thread
                Function("checkThread") { () -> Bool in
                    Thread.isMainThread
                }.runInBackground()
            }
        }
        
        let service = BackgroundService()
        // Call from a background task - should stay on background
        let result = try await Task.detached {
            try await service.handleCall(method: "checkThread", args: [])
        }.value
        XCTAssertEqual(result as? Bool, false, "Sync function with runInBackground() should NOT run on main thread")
    }
    
    // MARK: - Convertible Tests
    
    func testURLConversion() throws {
        // Test string to URL
        let url1 = try ArgumentConverter.convert("https://example.com/path", to: URL.self)
        XCTAssertEqual(url1.absoluteString, "https://example.com/path")
        
        // Test file path
        let url2 = try ArgumentConverter.convert("/Users/test/file.txt", to: URL.self)
        XCTAssertTrue(url2.isFileURL)
        XCTAssertEqual(url2.path, "/Users/test/file.txt")
    }
    
    func testDateConversion() throws {
        // Test ISO8601 string
        let dateString = "2024-01-15T10:30:00Z"
        let date1 = try ArgumentConverter.convert(dateString, to: Date.self)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let expected = formatter.date(from: dateString)!
        
        XCTAssertEqual(date1.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
        
        // Test timestamp (milliseconds)
        let timestamp: Double = 1705315800000  // Jan 15, 2024 10:30:00 UTC
        let date2 = try ArgumentConverter.convert(timestamp, to: Date.self)
        XCTAssertEqual(date2.timeIntervalSince1970, 1705315800, accuracy: 1.0)
    }
    
    func testDataConversion() throws {
        // Test Base64 string
        let base64 = "SGVsbG8gV29ybGQ="  // "Hello World"
        let data1 = try ArgumentConverter.convert(base64, to: Data.self)
        XCTAssertEqual(String(data: data1, encoding: .utf8), "Hello World")
        
        // Test byte array
        let bytes: [UInt8] = [72, 101, 108, 108, 111]  // "Hello"
        let data2 = try ArgumentConverter.convert(bytes, to: Data.self)
        XCTAssertEqual(String(data: data2, encoding: .utf8), "Hello")
    }
    
    func testCGPointConversion() throws {
        // Test from array
        let point1 = try ArgumentConverter.convert([10.0, 20.0], to: CGPoint.self)
        XCTAssertEqual(point1.x, 10.0)
        XCTAssertEqual(point1.y, 20.0)
        
        // Test from dictionary
        let point2 = try ArgumentConverter.convert(["x": 15.0, "y": 25.0], to: CGPoint.self)
        XCTAssertEqual(point2.x, 15.0)
        XCTAssertEqual(point2.y, 25.0)
    }
    
    func testCGSizeConversion() throws {
        // Test from array
        let size1 = try ArgumentConverter.convert([100.0, 200.0], to: CGSize.self)
        XCTAssertEqual(size1.width, 100.0)
        XCTAssertEqual(size1.height, 200.0)
        
        // Test from dictionary
        let size2 = try ArgumentConverter.convert(["width": 150.0, "height": 250.0], to: CGSize.self)
        XCTAssertEqual(size2.width, 150.0)
        XCTAssertEqual(size2.height, 250.0)
    }
    
    func testCGRectConversion() throws {
        // Test from array
        let rect1 = try ArgumentConverter.convert([10.0, 20.0, 100.0, 200.0], to: CGRect.self)
        XCTAssertEqual(rect1.origin.x, 10.0)
        XCTAssertEqual(rect1.origin.y, 20.0)
        XCTAssertEqual(rect1.width, 100.0)
        XCTAssertEqual(rect1.height, 200.0)
        
        // Test from dictionary
        let rect2 = try ArgumentConverter.convert(
            ["x": 15.0, "y": 25.0, "width": 150.0, "height": 250.0],
            to: CGRect.self
        )
        XCTAssertEqual(rect2.origin.x, 15.0)
        XCTAssertEqual(rect2.origin.y, 25.0)
        XCTAssertEqual(rect2.width, 150.0)
        XCTAssertEqual(rect2.height, 250.0)
    }
    
    func testNumericConversion() throws {
        // Int to Double
        let double1 = try ArgumentConverter.convert(42, to: Double.self)
        XCTAssertEqual(double1, 42.0)
        
        // Double to Int
        let int1 = try ArgumentConverter.convert(42.7, to: Int.self)
        XCTAssertEqual(int1, 42)
        
        // NSNumber to various types
        let number = NSNumber(value: 123.456)
        let asDouble = try ArgumentConverter.convert(number, to: Double.self)
        XCTAssertEqual(asDouble, 123.456, accuracy: 0.001)
        
        let asInt = try ArgumentConverter.convert(number, to: Int.self)
        XCTAssertEqual(asInt, 123)
    }
    
    // MARK: - Dictionary Parameter Extraction Tests (for Codable params)
    
    func testDictionaryParameterExtraction() async throws {
        class CounterService: NativeRPCService {
            override class var serviceName: String { "counter" }
            
            private var count = 0
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                Function("add") { [weak self] (params: ValueParams) -> Int in
                    guard let self = self else { return 0 }
                    self.count += params.value
                    return self.count
                }
                
                Function("getValue") { [weak self] () -> Int in
                    self?.count ?? 0
                }
            }
        }
        
        let service = CounterService()
        
        // Test with dictionary containing value
        let result1 = try await service.handleCall(method: "add", args: [["value": 5]])
        XCTAssertEqual(result1 as? Int, 5)
        
        // Test with another add
        let result2 = try await service.handleCall(method: "add", args: [["value": 10]])
        XCTAssertEqual(result2 as? Int, 15)  // 5 + 10 = 15
        
        // Verify final count
        let finalCount = try await service.handleCall(method: "getValue", args: [])
        XCTAssertEqual(finalCount as? Int, 15)
    }
    
    func testDictionaryParameterExtractionAsync() async throws {
        class AsyncCounterService: NativeRPCService {
            override class var serviceName: String { "asyncCounter" }
            
            private var count = 0
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                AsyncFunction("addDelayed") { [weak self] (params: ValueParams) async -> Int in
                    guard let self = self else { return 0 }
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    self.count += params.value
                    return self.count
                }
            }
        }
        
        let service = AsyncCounterService()
        
        // Test with dictionary containing value
        let result = try await service.handleCall(method: "addDelayed", args: [["value": 7]])
        XCTAssertEqual(result as? Int, 7)
    }
    
    func testMultiParameterCodable() async throws {
        class MathService: NativeRPCService, @unchecked Sendable {
            override class var serviceName: String { "math" }
            
            @ServiceDefinitionBuilder
            override func definition() -> ServiceDefinitionContainer {
                // Two-parameter function using Codable struct
                Function("addTwo") { (params: AddParams) -> Int in
                    params.a + params.b
                }
            }
        }
        
        let service = MathService()
        
        // Test with dictionary containing both values
        let result = try await service.handleCall(method: "addTwo", args: [["a": 3, "b": 7]])
        XCTAssertEqual(result as? Int, 10)
    }
}
