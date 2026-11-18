import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

const _devices = [
  PreviewDevice(preset: DevicePresets.iPhoneSe3),
  PreviewDevice(preset: DevicePresets.iPhone17, textScale: 1.5),
];

class _ProbeApp extends StatelessWidget {
  const _ProbeApp(this.slot);

  final DeviceSlot slot;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: ValueKey('open.${slot.index}'),
              onPressed: () => showDialog<void>(
                context: context,
                useRootNavigator: true,
                builder: (_) => Text('dialog.${slot.index}'),
              ),
              child: Text('device ${slot.index}'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiDevicePreview(
      devices: _devices,
      appBuilder: (context, slot) => _ProbeApp(slot),
    ),
  );
}

void main() {
  testWidgets('builds one app instance per device with its own metrics', (
    tester,
  ) async {
    await _pump(tester);

    for (var i = 0; i < _devices.length; i++) {
      final screen = find.byKey(DeviceSlot.screenKeyOf(i));
      expect(screen, findsOneWidget);
      final mediaQuery = MediaQuery.of(tester.element(screen));
      expect(mediaQuery.size, _devices[i].screenSize);
      expect(mediaQuery.textScaler, TextScaler.linear(_devices[i].textScale));
      expect(mediaQuery.padding, _devices[i].preset.portraitPadding);
      expect(
        find.descendant(of: screen, matching: find.text('device $i')),
        findsOneWidget,
      );
    }
  });

  testWidgets('the tool adds no Navigator above the devices', (tester) async {
    await _pump(tester);

    for (var i = 0; i < _devices.length; i++) {
      final screen = find.byKey(DeviceSlot.screenKeyOf(i));
      expect(
        find.ancestor(of: screen, matching: find.byType(Navigator)),
        findsNothing,
      );
    }
  });

  testWidgets('a root-navigator dialog opens inside its own device', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('open.1')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(DeviceSlot.screenKeyOf(1)),
        matching: find.text('dialog.1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(DeviceSlot.screenKeyOf(0)),
        matching: find.text('dialog.1'),
      ),
      findsNothing,
    );
  });

  testWidgets('a hot reload does not call appBuilder again', (tester) async {
    final calls = <int, int>{};
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MultiDevicePreviewController(devices: _devices);
    await tester.pumpWidget(
      MultiDevicePreview(
        controller: controller,
        appBuilder: (context, slot) {
          calls.update(slot.index, (count) => count + 1, ifAbsent: () => 1);
          return _ProbeApp(slot);
        },
      ),
    );
    expect(calls, {0: 1, 1: 1});

    // What a hot reload does to the widget tree.
    tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
    await tester.pump();
    expect(calls, {0: 1, 1: 1});

    // Changing a device keeps the app, and so what appBuilder created.
    controller.setDevice(
      0,
      const PreviewDevice(preset: DevicePresets.iPhone17, textScale: 2),
    );
    await tester.pump();
    expect(calls, {0: 1, 1: 1});

    controller.restart();
    await tester.pump();
    expect(calls, {0: 2, 1: 2});
  });

  testWidgets('appBuilder runs again when what it read from context changes', (
    tester,
  ) async {
    final scales = <double>[];
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MultiDevicePreviewController(
      devices: const [PreviewDevice(preset: DevicePresets.iPhoneSe3)],
    );
    await tester.pumpWidget(
      MultiDevicePreview(
        controller: controller,
        appBuilder: (context, slot) {
          scales.add(MediaQuery.textScalerOf(context).scale(1));
          return _ProbeApp(slot);
        },
      ),
    );
    expect(scales, [1]);

    controller.setDevice(
      0,
      const PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 2),
    );
    await tester.pump();
    expect(scales, [1, 2]);
  });
}
