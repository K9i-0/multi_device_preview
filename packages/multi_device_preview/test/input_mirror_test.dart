import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/sync/input_gate.dart';

import 'support.dart';

void main() {
  late MultiDevicePreviewController controller;

  setUp(() => controller = MultiDevicePreviewController(devices: tallAndShort));
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Duration loadingDelay = Duration.zero,
  }) => pumpPreview(
    tester,
    controller: controller,
    appBuilder: (context, slot) =>
        ProbeApp(loadingDelay: slot.index == 0 ? Duration.zero : loadingDelay),
  );

  testWidgets('a tap on the source device is sent to the others', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
    expect(probeOf(tester, 1).count, 1);
    expect(controller.outOfSyncDevices, isEmpty);
  });

  testWidgets('an icon button is matched by its tooltip', (tester) async {
    await pump(tester);

    await tester.tap(inDevice(0, find.byTooltip('Favorite')));
    await settle(tester);

    expect(probeOf(tester, 1).favorites, 1);
    expect(controller.outOfSyncDevices, isEmpty);
  });

  testWidgets('a long press stays a long press', (tester) async {
    await pump(tester);

    await tester.longPress(inDevice(0, find.text('Row 2')));
    await settle(tester, frames: 20);

    expect(probeOf(tester, 0).lastItem, 'long Row 2');
    expect(probeOf(tester, 1).lastItem, 'long Row 2');
  });

  testWidgets('taps on other devices are not mirrored', (tester) async {
    await pump(tester);

    await tester.tap(inDevice(1, find.text('Increment')));
    await settle(tester);

    expect(probeOf(tester, 0).count, 0);
    expect(probeOf(tester, 1).count, 1);
  });

  testWidgets('nothing is mirrored while sync is off', (tester) async {
    controller.syncEnabled = false;
    await pump(tester);

    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
    expect(probeOf(tester, 1).count, 0);
  });

  testWidgets('a gesture started before sync is turned off is completed', (
    tester,
  ) async {
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(inDevice(0, find.text('Increment'))),
    );
    await tester.pump();
    controller.syncEnabled = false;
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(probeOf(tester, 1).count, 1);
  });

  testWidgets('a target scrolled out of view is revealed, then tapped', (
    tester,
  ) async {
    await pump(tester);
    // Visible on the tall source device, below the fold on the short one.
    final row = find.text('Row 8');
    expect(inDevice(0, row).hitTestable(), findsOneWidget);
    expect(inDevice(1, row).hitTestable(), findsNothing);

    await tester.tap(inDevice(0, row));
    await settle(tester, frames: 20);

    expect(probeOf(tester, 0).lastItem, 'Row 8');
    expect(probeOf(tester, 1).lastItem, 'Row 8');
  });

  testWidgets('waits for the target to appear on a slower device', (
    tester,
  ) async {
    await pump(tester, loadingDelay: const Duration(seconds: 1));

    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester, frames: 30);

    expect(probeOf(tester, 1).count, 1);
    expect(controller.outOfSyncDevices, isEmpty);
  });

  testWidgets('gives up and marks the device when the target never appears', (
    tester,
  ) async {
    await pump(tester, loadingDelay: const Duration(seconds: 30));

    await tester.tap(inDevice(0, find.text('Increment')));
    await settle(tester, frames: 100);

    expect(controller.outOfSyncDevices, {1});
    // Let the loading timer finish.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('an imprecise tap is not sent and marks the device', (
    tester,
  ) async {
    var taps = 0;
    await pumpPreview(
      tester,
      controller: controller,
      appBuilder: (context, slot) => MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const Align(
              alignment: Alignment.topLeft,
              child: Text('top'),
            ),
          ),
        ),
      ),
    );

    // Empty space in a receiver covering the whole screen.
    await tester.tapAt(tester.getCenter(find.byKey(DeviceSlot.screenKeyOf(0))));
    await settle(tester);

    expect(taps, 1);
    expect(controller.outOfSyncDevices, {1});
  });

  testWidgets('a drag scrolls the other devices too', (tester) async {
    await pump(tester);

    await tester.drag(inDevice(0, find.text('Row 3')), const Offset(0, -300));
    await settle(tester, frames: 20);

    double offsetOf(int device) => tester
        .state<ScrollableState>(inDevice(device, find.byType(Scrollable)).first)
        .position
        .pixels;
    expect(offsetOf(0), greaterThan(100));
    expect(offsetOf(1), closeTo(offsetOf(0), 1));
  });

  testWidgets('a trackpad pan scrolls the other devices too', (tester) async {
    await pump(tester);

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(
      tester.getCenter(inDevice(0, find.text('Row 3'))),
    );
    for (var i = 1; i <= 10; i++) {
      await gesture.panZoomUpdate(
        tester.getCenter(inDevice(0, find.text('Row 3'))),
        pan: Offset(0, -20.0 * i),
      );
    }
    await gesture.panZoomEnd();
    await settle(tester, frames: 20);

    double offsetOf(int device) => tester
        .state<ScrollableState>(inDevice(device, find.byType(Scrollable)).first)
        .position
        .pixels;
    expect(offsetOf(0), greaterThan(100));
    expect(offsetOf(1), closeTo(offsetOf(0), 1));
  });

  testWidgets('a wheel scroll is sent to the other devices', (tester) async {
    await pump(tester);

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(inDevice(0, find.text('Row 3'))),
        scrollDelta: const Offset(0, 200),
      ),
    );
    await settle(tester, frames: 20);

    double offsetOf(int device) => tester
        .state<ScrollableState>(inDevice(device, find.byType(Scrollable)).first)
        .position
        .pixels;
    expect(offsetOf(0), 200);
    expect(offsetOf(1), 200);
  });

  testWidgets('synthesized events are never mirrored again', (tester) async {
    await pump(tester);
    final position = tester.getCenter(inDevice(0, find.text('Increment')));

    tester.binding.handlePointerEvent(
      PointerDownEvent(
        pointer: kSyntheticPointerBase - 1,
        device: kSyntheticDeviceBase + 9,
        position: position,
      ),
    );
    tester.binding.handlePointerEvent(
      PointerUpEvent(
        pointer: kSyntheticPointerBase - 1,
        device: kSyntheticDeviceBase + 9,
        position: position,
      ),
    );
    await settle(tester);

    expect(probeOf(tester, 0).count, 1);
    expect(probeOf(tester, 1).count, 0);
  });

  testWidgets('focus taken by a mirrored tap returns to the source', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(inDevice(0, find.byKey(const ValueKey('search'))));
    await settle(tester);

    final sourceField = tester.state<EditableTextState>(
      inDevice(0, find.byType(EditableText)).first,
    );
    expect(FocusManager.instance.primaryFocus, sourceField.widget.focusNode);
  });
}
