import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/layout.dart';

void main() {
  const se = PreviewDevice(preset: DevicePresets.iPhoneSe3);
  const iphone = PreviewDevice(preset: DevicePresets.iPhone17);

  group('PreviewDevice', () {
    test('frame outsets surround the screen exactly', () {
      final frame = DevicePresets.iPhone17.frame!;
      expect(iphone.outerSize, frame.size);
      expect(iphone.frameOutsets.left, frame.screenOffset.dx);
      expect(iphone.frameOutsets.top, frame.screenOffset.dy);
      expect(iphone.frameOutsets.right, greaterThanOrEqualTo(0));
      expect(iphone.frameOutsets.bottom, greaterThanOrEqualTo(0));
    });

    test('landscape swaps the size, uses landscape safe areas and rotates '
        'the frame', () {
      const preset = DevicePresets.iPadPro13M5;
      const landscape = PreviewDevice(
        preset: preset,
        orientation: Orientation.landscape,
      );
      expect(landscape.screenSize, const Size(1376, 1032));
      expect(landscape.simulation.screenSize, landscape.screenSize);
      expect(landscape.simulation.orientation, Orientation.landscape);
      expect(landscape.simulation.padding, preset.landscapePadding);
      expect(landscape.frameOutsets, const EdgeInsets.all(46));
      expect(landscape.outerSize, preset.frame!.size.flipped);

      const portrait = PreviewDevice(preset: preset);
      expect(portrait.screenSize, preset.portraitSize);
      expect(portrait.simulation.padding, preset.portraitPadding);
      expect(portrait.outerSize, preset.frame!.size);
    });

    test('orientation takes part in equality and copyWith', () {
      const landscape = PreviewDevice(
        preset: DevicePresets.iPhone17,
        orientation: Orientation.landscape,
      );
      expect(landscape, isNot(iphone));
      expect(iphone.copyWith(orientation: Orientation.landscape), landscape);
      expect(
        landscape.copyWith(textScale: 2).orientation,
        Orientation.landscape,
      );
      expect('$landscape', contains('landscape'));
    });

    test('a preset without a frame has no outsets', () {
      const window = PreviewDevice(
        preset: DevicePreset(
          id: 'custom',
          name: 'Custom',
          platform: TargetPlatform.iOS,
          portraitSize: Size(400, 800),
          devicePixelRatio: 2,
        ),
      );
      expect(window.frameOutsets, EdgeInsets.zero);
      expect(window.outerSize, window.screenSize);
    });
  });

  group('MultiDeviceLayout', () {
    const padding = EdgeInsets.all(10);
    const spacing = 20.0;

    test('places devices left to right, top aligned', () {
      final layout = MultiDeviceLayout.compute(
        devices: const [se, iphone],
        available: const Size(100000, 100000),
        spacing: spacing,
        padding: padding,
      );
      final first = layout.deviceRects[0];
      final second = layout.deviceRects[1];

      expect(first.size, se.screenSize);
      expect(
        first.topLeft,
        Offset(10 + se.frameOutsets.left, 10 + se.frameOutsets.top),
      );
      expect(
        second.left,
        10 + se.outerSize.width + spacing + iphone.frameOutsets.left,
      );
      expect(second.top, 10 + iphone.frameOutsets.top);
      expect(
        layout.contentSize,
        Size(
          10 + se.outerSize.width + spacing + iphone.outerSize.width + 10,
          10 +
              (se.outerSize.height > iphone.outerSize.height
                  ? se.outerSize.height
                  : iphone.outerSize.height) +
              10,
        ),
      );
    });

    test('never scales up', () {
      final layout = MultiDeviceLayout.compute(
        devices: const [se],
        available: const Size(100000, 100000),
      );
      expect(layout.scale, 1.0);
    });

    test('scales down to fit the tighter axis', () {
      final unscaled = MultiDeviceLayout.compute(
        devices: const [se, iphone],
        available: const Size(100000, 100000),
      ).contentSize;
      final available = Size(unscaled.width / 2, unscaled.height);
      final layout = MultiDeviceLayout.compute(
        devices: const [se, iphone],
        available: available,
      );
      expect(layout.scale, closeTo(0.5, 1e-9));
    });

    test('handles no devices', () {
      final layout = MultiDeviceLayout.compute(
        devices: const <PreviewDevice>[],
        available: const Size(800, 600),
        padding: padding,
      );
      expect(layout.deviceRects, isEmpty);
      expect(layout.contentSize, const Size(20, 20));
      expect(layout.scale, 1.0);
    });
  });
}
