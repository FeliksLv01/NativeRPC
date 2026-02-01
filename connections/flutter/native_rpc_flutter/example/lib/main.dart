// main.dart
// NativeRPC v2 Example
//
// Demonstrates using NativeRPC singleton to communicate with native services

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:native_rpc_flutter/native_rpc_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeRPC Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  static const _webViewChannel = MethodChannel('com.nativerpc.example/webview');

  int _count = 0;
  String _status = 'Initializing...';
  String? _error;
  String? _asyncResult;
  bool _isLoading = false;
  StreamSubscription<dynamic>? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize NativeRPC (optional - auto-initializes on first use)
      NativeRPC.init(channelName: 'native_rpc');

      // Subscribe to count changed events
      _subscribeToEvents();

      // Get initial value
      await _getValue();

      setState(() {
        _status = 'Connected';
        _error = null;
      });
    } catch (e) {
      setState(() {
        _status = 'Error';
        _error = e.toString();
      });
    }
  }

  void _subscribeToEvents() {
    // Subscribe to countChanged events using the stream API
    _eventSubscription = NativeRPC.stream('counter.countChanged').listen(
      (data) {
        setState(() {
          _count = data['count'] as int? ?? _count;
        });
      },
      onError: (e) {
        debugPrint('[Example] Event error: $e');
      },
    );
  }

  Future<void> _getValue() async {
    try {
      final value = await NativeRPC.call<int>('counter.getValue');
      setState(() {
        _count = value;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'getValue failed: $e';
      });
    }
  }

  Future<void> _increment() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.increment');
      setState(() {
        _count = newValue;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'increment failed: $e';
      });
    }
  }

  Future<void> _decrement() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.decrement');
      setState(() {
        _count = newValue;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'decrement failed: $e';
      });
    }
  }

  Future<void> _add(int value) async {
    try {
      final newValue = await NativeRPC.call<int>('counter.add', {
        'value': value,
      });
      setState(() {
        _count = newValue;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'add failed: $e';
      });
    }
  }

  Future<void> _reset() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.reset');
      setState(() {
        _count = newValue;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'reset failed: $e';
      });
    }
  }

  // MARK: - Async Function Examples

  /// Test: getValueDelayed - async function with delay parameter
  Future<void> _getValueDelayed() async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      // Call with 1000ms delay
      final value = await NativeRPC.call<int>('counter.getValueDelayed', {
        'delayMs': 1000,
      });
      stopwatch.stop();

      setState(() {
        _asyncResult =
            'getValueDelayed: $value (took ${stopwatch.elapsedMilliseconds}ms)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'getValueDelayed failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Test: getValueOnMain - async function that runs on main thread
  Future<void> _getValueOnMain() async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final value = await NativeRPC.call<int>('counter.getValueOnMain');
      setState(() {
        _asyncResult = 'getValueOnMain: $value (ran on main thread)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'getValueOnMain failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Test: addDelayed - async function with multiple parameters
  Future<void> _addDelayed() async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      // Add 5 with 500ms delay
      final newValue = await NativeRPC.call<int>('counter.addDelayed', {
        'value': 5,
        'delayMs': 500,
      });
      stopwatch.stop();

      setState(() {
        _count = newValue;
        _asyncResult =
            'addDelayed: added 5, new value = $newValue (took ${stopwatch.elapsedMilliseconds}ms)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'addDelayed failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Test: divideBy - async function that can throw errors
  Future<void> _divideBy(int divisor) async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final result = await NativeRPC.call<int>('counter.divideBy', {
        'divisor': divisor,
      });
      setState(() {
        _asyncResult = 'divideBy($divisor): $_count / $divisor = $result';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'divideBy($divisor) failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Test: fetchRemoteValue - Promise-based async function
  Future<void> _fetchRemoteValue() async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final result = await NativeRPC.call<Map<String, dynamic>>(
        'counter.fetchRemoteValue',
      );
      stopwatch.stop();

      setState(() {
        _asyncResult =
            'fetchRemoteValue: remoteValue=${result['remoteValue']}, '
            'timestamp=${result['timestamp']} (took ${stopwatch.elapsedMilliseconds}ms)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'fetchRemoteValue failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Test: multiplyAsync - Promise-based async with parameters
  Future<void> _multiplyAsync(int multiplier) async {
    setState(() {
      _isLoading = true;
      _asyncResult = null;
      _error = null;
    });

    try {
      final stopwatch = Stopwatch()..start();
      final result = await NativeRPC.call<int>('counter.multiplyAsync', {
        'multiplier': multiplier,
      });
      stopwatch.stop();

      setState(() {
        _asyncResult =
            'multiplyAsync($multiplier): $_count × $multiplier = $result '
            '(took ${stopwatch.elapsedMilliseconds}ms)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'multiplyAsync($multiplier) failed: $e';
        _isLoading = false;
      });
    }
  }

  /// Open the native WebView page with the web demo
  Future<void> _openWebDemo() async {
    try {
      await _webViewChannel.invokeMethod('openWebView');
    } catch (e) {
      setState(() {
        _error = 'Failed to open web demo: $e';
      });
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    NativeRPC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('NativeRPC Counter'),
        actions: [
          IconButton(
            onPressed: _openWebDemo,
            icon: const Icon(Icons.web),
            tooltip: 'Open Web Demo',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Status indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _status == 'Connected'
                        ? Colors.green.shade100
                        : _status == 'Error'
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Status: $_status',
                    style: TextStyle(
                      color: _status == 'Connected'
                          ? Colors.green.shade800
                          : _status == 'Error'
                          ? Colors.red.shade800
                          : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Counter display
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Counter Value:',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '$_count',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sync function buttons
              _buildSectionHeader('Sync Functions'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _decrement,
                    icon: const Icon(Icons.remove),
                    label: const Text('Decrement'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _increment,
                    icon: const Icon(Icons.add),
                    label: const Text('Increment'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _add(5),
                    child: const Text('Add 5'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _add(10),
                    child: const Text('Add 10'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 24),

              // Async function buttons
              _buildSectionHeader('Async Functions (Swift async/await)'),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: !_isLoading ? _getValueDelayed : null,
                    child: const Text('getValueDelayed (1s)'),
                  ),
                  ElevatedButton(
                    onPressed: !_isLoading ? _getValueOnMain : null,
                    child: const Text('getValueOnMain'),
                  ),
                  ElevatedButton(
                    onPressed: !_isLoading ? _addDelayed : null,
                    child: const Text('addDelayed (+5, 0.5s)'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: !_isLoading ? () => _divideBy(2) : null,
                    child: const Text('divideBy(2)'),
                  ),
                  ElevatedButton(
                    onPressed: !_isLoading ? () => _divideBy(0) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                    ),
                    child: const Text('divideBy(0) - Error'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Promise-based async function buttons
              _buildSectionHeader('Async Functions (Promise-based)'),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: !_isLoading ? _fetchRemoteValue : null,
                    child: const Text('fetchRemoteValue'),
                  ),
                  ElevatedButton(
                    onPressed: !_isLoading ? () => _multiplyAsync(3) : null,
                    child: const Text('multiplyAsync(3)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Loading indicator
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Async result display
              if (_asyncResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Async Result:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _asyncResult!,
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
              ],

              // Refresh button
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _getValue,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Value'),
                ),
              ),

              // Error display
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
