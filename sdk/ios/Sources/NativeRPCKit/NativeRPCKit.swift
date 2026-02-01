// NativeRPCKit.swift
// NativeRPCKit v2
//
// Public API exports

// Re-export all public types for convenient importing

// Core
@_exported import struct Foundation.Data
@_exported import struct Foundation.UUID

// The module exports are automatic in Swift Package Manager
// All public types from the following files are available:

// Core/
// - NativeRPCMessage.swift: NativeRPCMessageType, NativeRPCRequest, NativeRPCResponse, NativeRPCEvent, NativeRPCSubscription, NativeRPCErrorInfo
// - NativeRPCError.swift: NativeRPCError
// - NativeRPCService.swift: NativeRPCServiceProtocol, NativeRPCHostProtocol, NativeRPCService, AnyNativeRPCService
// - NativeRPCHost.swift: NativeRPCHost, ServiceInfo

// DSL/
// - ServiceDefinition.swift: AnyDefinition, AnyServiceDefinitionElement, AnySyncFunction, AnyAsyncFunction, SyncFunctionDefinition, AsyncFunctionDefinition, ConstantDefinition, ServiceNameDefinition, EventsDefinition, EventObservingType, EventObservingDefinition, LifecycleType, LifecycleDefinition
// - ServiceDefinitionBuilder.swift: ServiceDefinitionContainer, ServiceDefinitionBuilder
// - DSLFactories.swift: Name(), Constant(), Function(), AsyncFunction(), Events(), OnStartObserving(), OnStopObserving(), OnCreate(), OnDestroy(), OnActivityEntersForeground(), OnActivityEntersBackground()

// Codable/
// - AnyCodable.swift: AnyCodable

// Connection/
// - NativeRPCConnection.swift: NativeRPCConnection, BaseNativeRPCConnection, CallbackConnection, InMemoryConnectionPair
// Note: FlutterMethodChannelConnection is provided by native_rpc_flutter plugin

// WebView/
// - WebViewNativeRPCBridge.swift: WebViewNativeRPCBridge, WebViewConnection (WKWebView support)
// Note: Only available when WebKit is available (iOS, macOS)
