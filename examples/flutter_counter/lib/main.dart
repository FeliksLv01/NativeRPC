import 'package:flutter/material.dart';
import 'package:native_rpc_flutter/native_rpc_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeRPC Counter',
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
  int _counter = 0;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeRPC();
  }

  void _initializeRPC() {
    // Subscribe to count changed events using simple API
    NativeRPC.on('counter.countChanged', (data) {
      setState(() {
        _counter = data['count'] as int;
        _status = 'Connected';
      });
    });

    // Get initial value
    _getInitialValue();
  }

  Future<void> _getInitialValue() async {
    try {
      final value = await NativeRPC.call<int>('counter.getValue');
      setState(() {
        _counter = value;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _status = 'Error getting value: $e';
      });
    }
  }

  Future<void> _incrementCounter() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.increment');
      setState(() {
        _counter = newValue;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _decrementCounter() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.decrement');
      setState(() {
        _counter = newValue;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _resetCounter() async {
    try {
      final newValue = await NativeRPC.call<int>('counter.reset');
      setState(() {
        _counter = newValue;
        _status = 'Connected';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('NativeRPC Counter'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _status,
              style: TextStyle(
                color: _status.startsWith('Error') ? Colors.red : Colors.green,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Counter value from native:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text('$_counter', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _decrementCounter,
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _resetCounter,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
