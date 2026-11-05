import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

import 'support.dart';

void main() {
  late MultiDevicePreviewController controller;
  late List<int> shortcutPresses;

  setUp(() {
    controller = MultiDevicePreviewController(
      devices: const [
        PreviewDevice(preset: DevicePresets.iPhone17ProMax),
        PreviewDevice(preset: DevicePresets.iPhoneSe3),
        PreviewDevice(preset: DevicePresets.pixel9),
      ],
    );
    shortcutPresses = [0, 0, 0];
  });
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) async {
    await pumpPreview(
      tester,
      controller: controller,
      // A keyboard shortcut above the app's Navigator, like a debug menu
      // opened with Shift+D.
      appBuilder: (context, slot) => _ShortcutApp(
        onShortcut: () => shortcutPresses[slot.index]++,
      ),
    );
    await tester.pump();
  }

  Future<void> pressShortcut(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  testWidgets('keyboard shortcuts reach the first device after start-up', (
    tester,
  ) async {
    await pump(tester);

    await pressShortcut(tester);

    expect(shortcutPresses, [1, 0, 0]);
  });

  testWidgets('keyboard shortcuts reach the first device after a mirrored '
      'tap', (tester) async {
    await pump(tester);

    await tester.tap(inDevice(0, find.text('Tap')));
    await settle(tester);
    await pressShortcut(tester);

    expect(shortcutPresses, [1, 0, 0]);
  });

  testWidgets('a text field focused on the first device keeps the focus', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(inDevice(0, find.byType(TextField)));
    await settle(tester);

    final field = tester.state<EditableTextState>(
      inDevice(0, find.byType(EditableText)),
    );
    expect(FocusManager.instance.primaryFocus, field.widget.focusNode);
  });

  testWidgets('other devices can take the focus while syncing is off', (
    tester,
  ) async {
    controller.syncEnabled = false;
    await pump(tester);

    await tester.tap(inDevice(2, find.byType(TextField)));
    await tester.pump();

    final field = tester.state<EditableTextState>(
      inDevice(2, find.byType(EditableText)),
    );
    expect(FocusManager.instance.primaryFocus, field.widget.focusNode);
  });
}

class _ShortcutApp extends StatelessWidget {
  const _ShortcutApp({required this.onShortcut});

  final VoidCallback onShortcut;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyD, shift: true):
              onShortcut,
        },
        child: child!,
      ),
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('Tap')),
            const TextField(),
          ],
        ),
      ),
    );
  }
}
