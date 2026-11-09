import 'package:device_preview/device_preview.dart';
import 'package:device_preview/svg.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/presets.dart';

import 'support.dart';

void main() {
  test('the iPhone Duo has a side status bar in its right strip', () {
    expect(sideStatusBarOf(DevicePresets.iPhone17), isNull);
    for (final preset in MultiDevicePresets.all) {
      final bar = sideStatusBarOf(preset)!;
      final drawing = SvgDrawing.parse(bar.artwork);
      expect(drawing.isEmpty, isFalse);
      // It fits in the right safe area.
      expect(
        bar.right + drawing.size.width,
        lessThanOrEqualTo(preset.portraitPadding.right),
      );
      // No top status bar: the strip is the only inset besides the bottom.
      expect(preset.portraitPadding.top, 0);
      expect(preset.systemUi?.statusBar, isNull);
    }
  });

  test('the closed iPhone Duo matches the simulator safe areas', () {
    const preset = MultiDevicePresets.iPhoneDuo;
    expect(
      preset.portraitPadding,
      const EdgeInsets.only(right: 84, bottom: 34),
    );
    expect(
      preset.resolve(orientation: Orientation.landscape).padding,
      const EdgeInsets.only(left: 84, bottom: 34),
    );
    // The open one rotated is the upright inner display, without a strip.
    expect(
      MultiDevicePresets.iPhoneDuoOpen
          .resolve(orientation: Orientation.landscape)
          .padding,
      const EdgeInsets.only(top: 82, bottom: 34),
    );
  });

  test('the closed iPhone Duo camera hole sits in the right strip', () {
    // Measured with `simctl io --display=1 --mask=black` on iOS 27.2.
    final screen = parseSvgPathData(
      MultiDevicePresets.iPhoneDuo.frame!.screenPath,
    );
    expect(screen.contains(const Offset(418, 47.67)), isFalse);
    // The app area along the top edge is not cut.
    expect(screen.contains(const Offset(233, 30)), isTrue);
    expect(screen.contains(const Offset(380, 47.67)), isTrue);
    expect(screen.contains(const Offset(418, 80)), isTrue);
  });

  testWidgets('the status bar time replaces the preset artwork', (
    tester,
  ) async {
    final controller = MultiDevicePreviewController(
      devices: const [
        PreviewDevice(preset: MultiDevicePresets.iPhoneDuo),
        PreviewDevice(preset: MultiDevicePresets.iPhoneDuoOpen),
        PreviewDevice(preset: DevicePresets.pixel9),
      ],
    );
    addTearDown(controller.dispose);
    await pumpPreview(
      tester,
      controller: controller,
      appBuilder: (context, slot) => const ProbeApp(),
      statusBarTime: '10:30',
    );

    final frames = tester.widgetList<DevicePreviewFrame>(
      find.byType(DevicePreviewFrame),
    );
    expect(frames, hasLength(3));
    for (final frame in frames) {
      final statusBar = frame.simulation.value!.systemUi?.statusBar;
      expect(statusBar?.leading ?? '', isEmpty);
    }
    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.foregroundPainter)
        .whereType<CustomPainter>()
        .where((painter) => '$painter'.contains('10:30'));
    expect(painters, hasLength(3));
    expect(tester.takeException(), isNull);
  });
}
