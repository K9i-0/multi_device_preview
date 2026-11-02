import 'package:flutter/material.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

void main() {
  runMultiDevicePreview(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhone17, textScale: 1.5),
      PreviewDevice(preset: DevicePresets.pixel9),
    ],
    appBuilder: (context, slot) => const ExampleApp(),
  );
}

/// A small app with a list, a form and a dialog, to look at layouts across
/// devices.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('multi_device_preview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tapped $_count times',
            key: const ValueKey('counter'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Search',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => setState(() => _count++),
                  child: const Text('Increment'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Dialog'),
                      content: const Text(
                        'Opened with the root navigator, inside this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Show dialog'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 1; i <= 20; i++)
            ListTile(
              leading: CircleAvatar(child: Text('$i')),
              title: Text('Item $i with a fairly long title'),
              subtitle: const Text('Subtitle that may wrap on small screens'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
