import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

import 'support.dart';

void main() {
  late MultiDevicePreviewController controller;

  setUp(() => controller = MultiDevicePreviewController(devices: tallAndShort));
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => pumpPreview(
    tester,
    controller: controller,
    appBuilder: (context, slot) => const ProbeApp(),
  );

  group('MultiDevicePreviewController', () {
    test('rejects an empty device list and removing the last device', () {
      expect(
        () => MultiDevicePreviewController(devices: const []),
        throwsAssertionError,
      );
      final single = MultiDevicePreviewController(devices: [tallAndShort[0]]);
      addTearDown(single.dispose);
      expect(() => single.removeDevice(0), throwsStateError);
    });

    test('notifies listeners only on changes', () {
      var notified = 0;
      controller.addListener(() => notified++);

      controller.setDevice(0, tallAndShort[0]);
      controller.syncEnabled = true;
      expect(notified, 0);

      controller.setDevice(0, tallAndShort[1]);
      controller.syncEnabled = false;
      controller.restart();
      expect(notified, 3);
      expect(controller.generation, 1);
    });

    test('keeps out-of-sync marks attached to devices', () {
      controller
        ..addDevice(const PreviewDevice(preset: DevicePresets.pixel9))
        ..markOutOfSync(2);
      expect(controller.outOfSyncDevices, {2});

      controller.removeDevice(0);
      expect(controller.outOfSyncDevices, {1});

      controller.restart();
      expect(controller.outOfSyncDevices, isEmpty);
    });

    test('captureScreenshot needs an attached preview', () {
      expect(controller.captureScreenshot, throwsStateError);
    });
  });

  testWidgets('switching the device keeps the app state', (tester) async {
    await pump(tester);
    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);

    controller.setDevice(
      1,
      const PreviewDevice(preset: DevicePresets.pixel9, textScale: 1.3),
    );
    await settle(tester);

    expect(probeOf(tester, 1).count, 1);
    final mediaQuery = MediaQuery.of(
      tester.element(find.byKey(DeviceSlot.screenKeyOf(1))),
    );
    expect(mediaQuery.size, DevicePresets.pixel9.portraitSize);
    expect(mediaQuery.textScaler, const TextScaler.linear(1.3));
  });

  testWidgets('restart rebuilds every app from scratch', (tester) async {
    await pump(tester);
    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);
    controller.markOutOfSync(1);

    controller.restart();
    await settle(tester);

    expect(probeOf(tester, 0).count, 0);
    expect(probeOf(tester, 1).count, 0);
    expect(controller.outOfSyncDevices, isEmpty);
  });

  testWidgets('removing a device keeps the state of the others', (
    tester,
  ) async {
    controller.syncEnabled = false;
    await pump(tester);
    await tester.tap(inDevice(1, find.text('Increment')));
    await settle(tester);

    controller.removeDevice(0);
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
  });

  testWidgets('the status bar follows the app bar of each device', (
    tester,
  ) async {
    await pump(tester);
    await settle(tester);

    final frames = tester.widgetList<DevicePreviewFrame>(
      find.byType(DevicePreviewFrame),
    );
    for (final frame in frames) {
      // ProbeApp has a black app bar, so the status bar icons are light.
      expect(
        frame.overlayStyle!.value?.statusBarIconBrightness,
        Brightness.light,
      );
    }
  });

  testWidgets('captures the preview and a single device as PNG', (
    tester,
  ) async {
    await pump(tester);

    Future<List<int>> capture({int? device}) async {
      return completeWithRealAsync(
        tester,
        controller.captureScreenshot(device: device),
      );
    }

    const pngSignature = [0x89, 0x50, 0x4E, 0x47];
    expect((await capture()).take(4), pngSignature);
    expect((await capture(device: 1)).take(4), pngSignature);
  });
}
