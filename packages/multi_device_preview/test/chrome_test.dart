import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/chrome.dart';

import 'support.dart';

Future<void> selectPreset(WidgetTester tester, DevicePreset preset) async {
  final tile = find.byKey(ChromeKeys.preset(preset.id));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(ChromeKeys.sheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  late MultiDevicePreviewController controller;

  setUp(() => controller = MultiDevicePreviewController(devices: tallAndShort));
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => pumpPreview(
    tester,
    controller: controller,
    appBuilder: (context, slot) => const ProbeApp(),
  );

  testWidgets('labels show the device and text scale', (tester) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byKey(ChromeKeys.label(1)),
        matching: find.text('${DevicePresets.iPhoneSe3.name} · 100%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sync switch and restart button drive the controller', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);

    await tester.tap(find.byKey(ChromeKeys.sync));
    await tester.pump();
    expect(controller.syncEnabled, isFalse);

    await tester.tap(find.byKey(ChromeKeys.restart));
    await settle(tester);
    expect(probeOf(tester, 0).count, 0);
  });

  testWidgets('tooltips work in the tool layer', (tester) async {
    await pump(tester);

    await tester.longPress(find.byKey(ChromeKeys.restart));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Restart all devices'), findsOneWidget);
  });

  testWidgets('the settings sheet changes, removes and adds devices', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);

    await tester.tap(find.byKey(ChromeKeys.label(1)));
    await tester.pumpAndSettle();
    expect(find.byKey(ChromeKeys.sheet), findsOneWidget);

    await tester.tap(find.byKey(ChromeKeys.textScale(1.5)));
    await tester.pumpAndSettle();
    expect(controller.devices[1].textScale, 1.5);

    await selectPreset(tester, DevicePresets.pixel9);
    expect(controller.devices[1].preset, DevicePresets.pixel9);
    expect(controller.devices[1].textScale, 1.5);
    expect(probeOf(tester, 1).count, 1, reason: 'state is kept');

    await tester.tap(find.byKey(ChromeKeys.remove));
    await tester.pumpAndSettle();
    expect(controller.devices, hasLength(1));
    expect(find.byKey(ChromeKeys.sheet), findsNothing);

    await tester.tap(find.byKey(ChromeKeys.add));
    await tester.pumpAndSettle();
    await selectPreset(tester, DevicePresets.iPhone17);
    expect(controller.devices.last.preset, DevicePresets.iPhone17);
  });

  testWidgets('tapping outside the sheet closes it', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(ChromeKeys.label(0)));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();

    expect(find.byKey(ChromeKeys.sheet), findsNothing);
  });

  testWidgets('out-of-sync devices are marked', (tester) async {
    await pump(tester);

    controller.markOutOfSync(1);
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(ChromeKeys.label(1)),
        matching: find.byIcon(Icons.sync_problem),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('out of sync'), findsOneWidget);
  });
}
