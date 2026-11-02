import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/sync/input_gate.dart';

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

  testWidgets('platform input reaches the source device', (tester) async {
    await pump(tester);

    platformTap(tester, tester.getCenter(inDevice(0, find.text('Increment'))));
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
    expect(probeOf(tester, 1).count, 1);
  });

  testWidgets('platform input to the other devices is blocked while synced', (
    tester,
  ) async {
    await pump(tester);

    platformTap(tester, tester.getCenter(inDevice(1, find.text('Increment'))));
    await settle(tester);

    expect(probeOf(tester, 0).count, 0);
    expect(probeOf(tester, 1).count, 0);
  });

  testWidgets('platform input reaches every device while sync is off', (
    tester,
  ) async {
    controller.syncEnabled = false;
    await pump(tester);

    platformTap(tester, tester.getCenter(inDevice(1, find.text('Increment'))));
    await settle(tester);

    expect(probeOf(tester, 1).count, 1);
  });

  testWidgets('injected input (Marionette, tests) is not blocked', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(inDevice(1, find.text('Increment')));
    await settle(tester);

    expect(probeOf(tester, 1).count, 1);
  });

  testWidgets('a mouse click acts as a touch', (tester) async {
    await pump(tester);

    platformTap(
      tester,
      tester.getCenter(inDevice(0, find.text('Increment'))),
      kind: ui.PointerDeviceKind.mouse,
    );
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
  });

  group('retargetMouseToTouch', () {
    ui.PointerData datum(
      ui.PointerChange change, {
      ui.PointerDeviceKind kind = ui.PointerDeviceKind.mouse,
      ui.PointerSignalKind signalKind = ui.PointerSignalKind.none,
    }) => ui.PointerData(
      change: change,
      kind: kind,
      signalKind: signalKind,
      physicalX: 10,
      physicalY: 20,
      buttons: 1,
    );

    test('relabels mouse pointers and drops their hover', () {
      final packet = retargetMouseToTouch(
        ui.PointerDataPacket(
          data: [
            datum(ui.PointerChange.hover),
            datum(ui.PointerChange.down),
            datum(ui.PointerChange.move),
          ],
        ),
      );
      expect(packet.data.map((d) => d.change), [
        ui.PointerChange.down,
        ui.PointerChange.move,
      ]);
      expect(
        packet.data.map((d) => d.kind),
        everyElement(ui.PointerDeviceKind.touch),
      );
      expect(packet.data.first.physicalX, 10);
      expect(packet.data.first.buttons, 1);
    });

    test('keeps wheel signals and other kinds as they are', () {
      final original = ui.PointerDataPacket(
        data: [
          datum(
            ui.PointerChange.hover,
            signalKind: ui.PointerSignalKind.scroll,
          ),
          datum(ui.PointerChange.down, kind: ui.PointerDeviceKind.trackpad),
        ],
      );
      expect(identical(retargetMouseToTouch(original), original), isTrue);
    });
  });
}
