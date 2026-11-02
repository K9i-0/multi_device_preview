// A preview entry point that AI agents can drive through Marionette MCP:
//
//   flutter run -d macos -t <this file>
//
// See packages/multi_device_preview/example/marionette/main.dart in the
// repository for a complete app.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_marionette/multi_device_preview_marionette.dart';

void main() {
  final controller = MultiDevicePreviewController(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
    ],
  );
  if (!kReleaseMode) {
    // Before runMultiDevicePreview, so the binding is Marionette's.
    MarionetteBinding.ensureInitialized(
      multiDevicePreviewMarionetteConfiguration,
    );
    registerMultiDevicePreviewMarionetteExtensions(controller);
  }
  runMultiDevicePreview(
    controller: controller,
    appBuilder: (context, slot) => const CounterApp(),
  );
}

/// The app under preview.
class CounterApp extends StatefulWidget {
  /// Creates the app.
  const CounterApp({super.key});

  @override
  State<CounterApp> createState() => _CounterAppState();
}

class _CounterAppState extends State<CounterApp> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Counter')),
        body: Center(child: Text('Pressed $_count times')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Increment',
          onPressed: () => setState(() => _count++),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
