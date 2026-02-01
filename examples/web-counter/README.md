# Web Counter Example

A React + Vite web application that demonstrates NativeRPC Web SDK usage.

This example is designed to run inside a native WebView (iOS WKWebView or Android WebView) and communicate with native services via NativeRPC.

## Usage

This web app works in conjunction with the Flutter example app at `connections/flutter/native_rpc_flutter/example/`. The Flutter app provides a WebView page that loads this web app.

## Features

- Calls native `counter` service methods (`getValue`, `increment`, `decrement`, `add`, `reset`)
- Subscribes to `counter.countChanged` events
- Tests async methods (`getValueDelayed`, `divideBy`)
- Error handling demonstration (`divideBy(0)`)
