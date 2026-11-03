import 'package:device_preview/svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/presets.dart';

void main() {
  test('only the open iPhone Duo has a side status bar', () {
    expect(sideStatusBarOf(MultiDevicePresets.iPhoneDuo), isNull);
    expect(sideStatusBarOf(DevicePresets.iPhone17), isNull);
    final bar = sideStatusBarOf(MultiDevicePresets.iPhoneDuoOpen)!;
    final drawing = SvgDrawing.parse(bar.artwork);
    expect(drawing.isEmpty, isFalse);
    // It fits in the right safe area.
    final padding = MultiDevicePresets.iPhoneDuoOpen.portraitPadding;
    expect(bar.right + drawing.size.width, lessThanOrEqualTo(padding.right));
  });
}
