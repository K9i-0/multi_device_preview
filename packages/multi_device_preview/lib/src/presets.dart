// The iPhone Duo is not in device_preview's catalog yet, so its presets live
// here. Replace them with the upstream ones once device_preview ships them.
//
// dart format off

import 'dart:ui' as ui;

import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Presets bundled with this package for devices that `device_preview` does
/// not cover yet. Use them like [DevicePresets].
///
/// The screen outlines follow the simulator's display masks; the rest of the
/// frame is a plain approximation. Screen sizes match the
/// screenshot sizes App Store Connect asks for at the preset's
/// [DevicePreset.devicePixelRatio].
abstract final class MultiDevicePresets {
  /// iPhone Duo, closed: the 5.4" outer display.
  ///
  /// 466×678 pt at 3x (1398×2034 px). Safe areas are measured in the iOS 27.2
  /// simulator: an 84 pt control strip on the right and no top inset. The
  /// status bar sits at the top of that strip, as on the open iPhone Duo. In
  /// landscape the strip follows the camera, which device_preview's rotation
  /// puts on the left.
  static const DevicePreset iPhoneDuo = DevicePreset(
    id: 'apple-iphone-duo',
    name: 'iPhone Duo',
    brand: 'Apple',
    year: 2026,
    platform: TargetPlatform.iOS,
    portraitSize: ui.Size(466, 678),
    devicePixelRatio: 3.0,
    portraitPadding: EdgeInsets.only(right: 84, bottom: 34),
    landscapePadding: EdgeInsets.only(left: 84, bottom: 34),
    kind: DeviceKind.foldable,
    frame: DeviceFrame(
      size: ui.Size(500, 712),
      screenOffset: ui.Offset(17, 17),
      screenPath:
          'M 390.37,0 C 416.67,0 426.2,2.74 435.82,7.88 C 445.43,13.02 452.98,20.57 458.12,30.18 C 463.26,39.8 466,49.33 466,75.63 L 466,602.37 C 466,628.67 463.26,638.2 458.12,647.82 C 452.98,657.43 445.43,664.98 435.82,670.12 C 426.2,675.26 416.67,678 390.37,678 L 10.26,678 C 6.69,678 5.4,677.63 4.09,676.93 C 2.79,676.23 1.77,675.21 1.07,673.91 C 0.37,672.6 0,671.31 0,667.74 L 0,10.26 C 0,6.69 0.37,5.4 1.07,4.09 C 1.77,2.79 2.79,1.77 4.09,1.07 C 5.4,0.37 6.69,0 10.26,0 Z M 277,11 H 189 A 18.5,18.5 0 0 0 189,48 H 277 A 18.5,18.5 0 0 0 277,11 Z',
      body:
          '<svg viewBox="0 0 500 712">\n'
          '  <path d="M 407.37,0 C 439.58,0 451.26,3.35 463.03,9.65 C 474.81,15.95 484.05,25.19 490.35,36.97 C 496.65,48.74 500,60.42 500,92.63 L 500,619.37 C 500,651.58 496.65,663.26 490.35,675.03 C 484.05,686.81 474.81,696.05 463.03,702.35 C 451.26,708.65 439.58,712 407.37,712 L 27.26,712 C 17.78,712 14.34,711.01 10.88,709.16 C 7.41,707.31 4.69,704.59 2.84,701.12 C 0.99,697.66 0,694.22 0,684.74 L 0,27.26 C 0,17.78 0.99,14.34 2.84,10.88 C 4.69,7.41 7.41,4.69 10.88,2.84 C 14.34,0.99 17.78,0 27.26,0 Z" fill="#7e7e7e"/>\n'
          '  <path d="M 407.37,2 C 438.88,2 450.31,5.28 461.83,11.44 C 473.35,17.6 482.4,26.65 488.56,38.17 C 494.72,49.69 498,61.12 498,92.63 L 498,619.37 C 498,650.88 494.72,662.31 488.56,673.83 C 482.4,685.35 473.35,694.4 461.83,700.56 C 450.31,706.72 438.88,710 407.37,710 L 27.26,710 C 18.48,710 15.29,709.09 12.08,707.37 C 8.87,705.65 6.35,703.13 4.63,699.92 C 2.91,696.71 2,693.52 2,684.74 L 2,27.26 C 2,18.48 2.91,15.29 4.63,12.08 C 6.35,8.87 8.87,6.35 12.08,4.63 C 15.29,2.91 18.48,2 27.26,2 Z" fill="#2c2c2c"/>\n'
          '  <path d="M 407.37,6 C 437.49,6 448.42,9.14 459.43,15.03 C 470.44,20.92 479.08,29.56 484.97,40.57 C 490.86,51.58 494,62.51 494,92.63 L 494,619.37 C 494,649.49 490.86,660.42 484.97,671.43 C 479.08,682.44 470.44,691.08 459.43,696.97 C 448.42,702.86 437.49,706 407.37,706 L 27.26,706 C 19.87,706 17.19,705.23 14.48,703.78 C 11.78,702.34 9.66,700.22 8.22,697.52 C 6.77,694.81 6,692.13 6,684.74 L 6,27.26 C 6,19.87 6.77,17.19 8.22,14.48 C 9.66,11.78 11.78,9.66 14.48,8.22 C 17.19,6.77 19.87,6 27.26,6 Z" fill="#000000"/>\n'
          '</svg>',
    ),
    systemUi: SystemUiSimulation(
      platform: TargetPlatform.iOS,
      navigationBar: SystemUiBar(
        center:
            '<svg viewBox="0 0 145 5">\n'
            '  <path d="M 2.5,0 H 142.5 A 2.5,2.5 0 0 1 145,2.5 V 2.5 A 2.5,2.5 0 0 1 142.5,5 H 2.5 A 2.5,2.5 0 0 1 0,2.5 V 2.5 A 2.5,2.5 0 0 1 2.5,0 Z" fill="currentColor"/>\n'
            '</svg>',
        bottomInset: 8,
      ),
    ),
  );

  /// iPhone Duo, open: the 7.6" inner display, in the landscape layout the
  /// simulator starts it in.
  ///
  /// 951×669 pt at 3x (2853×2007 px). Size and safe areas are measured in
  /// the iOS 27.2 simulator; iOS reports no display features for the fold.
  /// The status bar sits in the right safe area, as in the simulator.
  static const DevicePreset iPhoneDuoOpen = DevicePreset(
    id: 'apple-iphone-duo-open',
    name: 'iPhone Duo (open)',
    brand: 'Apple',
    year: 2026,
    platform: TargetPlatform.iOS,
    portraitSize: ui.Size(951, 669),
    devicePixelRatio: 3.0,
    portraitPadding: EdgeInsets.only(right: 84, bottom: 34),
    // Rotated, it is the inner display held upright: no strip.
    landscapePadding: EdgeInsets.only(top: 82, bottom: 34),
    kind: DeviceKind.foldable,
    frame: DeviceFrame(
      size: ui.Size(985, 703),
      screenOffset: ui.Offset(17, 17),
      screenPath:
          'M 882.5,0 C 906.32,0 914.96,2.48 923.66,7.14 C 932.37,11.79 939.21,18.63 943.86,27.34 C 948.52,36.04 951,44.68 951,68.5 L 951,600.5 C 951,624.32 948.52,632.96 943.86,641.66 C 939.21,650.37 932.37,657.21 923.66,661.86 C 914.96,666.52 906.32,669 882.5,669 L 68.5,669 C 44.68,669 36.04,666.52 27.34,661.86 C 18.63,657.21 11.79,650.37 7.14,641.66 C 2.48,632.96 0,624.32 0,600.5 L 0,68.5 C 0,44.68 2.48,36.04 7.14,27.34 C 11.79,18.63 18.63,11.79 27.34,7.14 C 36.04,2.48 44.68,0 68.5,0 Z',
      body:
          '<svg viewBox="0 0 985 703">\n'
          '  <path d="M 899.5,0 C 929.23,0 940.01,3.1 950.88,8.91 C 961.75,14.72 970.28,23.25 976.09,34.12 C 981.9,44.99 985,55.77 985,85.5 L 985,617.5 C 985,647.23 981.9,658.01 976.09,668.88 C 970.28,679.75 961.75,688.28 950.88,694.09 C 940.01,699.9 929.23,703 899.5,703 L 85.5,703 C 55.77,703 44.99,699.9 34.12,694.09 C 23.25,688.28 14.72,679.75 8.91,668.88 C 3.1,658.01 0,647.23 0,617.5 L 0,85.5 C 0,55.77 3.1,44.99 8.91,34.12 C 14.72,23.25 23.25,14.72 34.12,8.91 C 44.99,3.1 55.77,0 85.5,0 Z" fill="#7e7e7e"/>\n'
          '  <path d="M 899.5,2 C 928.53,2 939.06,5.02 949.68,10.7 C 960.29,16.38 968.62,24.71 974.3,35.32 C 979.98,45.94 983,56.47 983,85.5 L 983,617.5 C 983,646.53 979.98,657.06 974.3,667.68 C 968.62,678.29 960.29,686.62 949.68,692.3 C 939.06,697.98 928.53,701 899.5,701 L 85.5,701 C 56.47,701 45.94,697.98 35.32,692.3 C 24.71,686.62 16.38,678.29 10.7,667.68 C 5.02,657.06 2,646.53 2,617.5 L 2,85.5 C 2,56.47 5.02,45.94 10.7,35.32 C 16.38,24.71 24.71,16.38 35.32,10.7 C 45.94,5.02 56.47,2 85.5,2 Z" fill="#2c2c2c"/>\n'
          '  <path d="M 899.5,6 C 927.14,6 937.17,8.88 947.27,14.28 C 957.38,19.69 965.31,27.62 970.72,37.73 C 976.12,47.83 979,57.86 979,85.5 L 979,617.5 C 979,645.14 976.12,655.17 970.72,665.27 C 965.31,675.38 957.38,683.31 947.27,688.72 C 937.17,694.12 927.14,697 899.5,697 L 85.5,697 C 57.86,697 47.83,694.12 37.73,688.72 C 27.62,683.31 19.69,675.38 14.28,665.27 C 8.88,655.17 6,645.14 6,617.5 L 6,85.5 C 6,57.86 8.88,47.83 14.28,37.73 C 19.69,27.62 27.62,19.69 37.73,14.28 C 47.83,8.88 57.86,6 85.5,6 Z" fill="#000000"/>\n'
          '</svg>',
    ),
    systemUi: SystemUiSimulation(
      platform: TargetPlatform.iOS,
      navigationBar: SystemUiBar(
        center:
            '<svg viewBox="0 0 145 5">\n'
            '  <path d="M 2.5,0 H 142.5 A 2.5,2.5 0 0 1 145,2.5 V 2.5 A 2.5,2.5 0 0 1 142.5,5 H 2.5 A 2.5,2.5 0 0 1 0,2.5 V 2.5 A 2.5,2.5 0 0 1 2.5,0 Z" fill="currentColor"/>\n'
            '</svg>',
        bottomInset: 8,
      ),
    ),
  );

  /// The bundled presets.
  static const List<DevicePreset> all = [iPhoneDuo, iPhoneDuoOpen];
}

/// Every preset the preview offers: `device_preview`'s catalog followed by
/// [MultiDevicePresets].
@internal
const List<DevicePreset> allPresets = [
  ...DevicePresets.all,
  ...MultiDevicePresets.all,
];

/// Status bar items drawn in a side safe area instead of the top one, as iOS
/// does on the iPhone Duo: the time above a ring around the Wi-Fi mark.
/// The artwork leaves the time out; it is drawn as text, centered on it.
@internal
@immutable
class SideStatusBar {
  /// Creates side status bar artwork placed [right] from the right edge and
  /// [top] from the top of the screen.
  const SideStatusBar({
    required this.artwork,
    required this.right,
    required this.top,
    required this.timeBaseline,
    required this.timeHeight,
  });

  /// SVG artwork; `currentColor` follows the status bar icon color.
  final String artwork;

  /// Distance from the right edge of the screen, in logical pixels.
  final double right;

  /// Distance from the top of the screen, in logical pixels.
  final double top;

  /// The baseline of the time, from the top of the artwork.
  final double timeBaseline;

  /// The height of the digits of the time.
  final double timeHeight;
}

/// The side status bar of [preset], or null when its status bar is the usual
/// top one.
@internal
SideStatusBar? sideStatusBarOf(DevicePreset preset) =>
    preset.id == MultiDevicePresets.iPhoneDuoOpen.id ||
        preset.id == MultiDevicePresets.iPhoneDuo.id
    ? _duoStatusBar
    : null;

// Measured from the iOS 27.2 simulator on the open iPhone Duo: centered 48 pt
// from the right edge, the time 34 to 45 pt from the top. The closed one has
// the same 84 pt strip and uses the same placement.
const SideStatusBar _duoStatusBar = SideStatusBar(
  right: 26,
  top: 32,
  timeBaseline: 13.3,
  timeHeight: 11,
  artwork:
      '<svg viewBox="0 0 44 66">\n'
      '  <path d="M 4.25,55.34 A 20.3,20.3 0 1 1 39.75,55.34 A 1.5,1.5 0 0 1 37.13,53.89 A 17.3,17.3 0 1 0 6.87,53.89 A 1.5,1.5 0 0 1 4.25,55.34 Z" fill="currentColor"/>\n'
      '  <g transform="translate(-279.61, 26.67) scale(0.33)" fill="currentColor">\n'
      '    <path d="M913.959 50.8742C920.859 50.8745 927.494 53.5806 932.495 58.4331C932.871 58.8077 933.473 58.803 933.844 58.4225L937.443 54.7146C937.631 54.5216 937.736 54.2601 937.734 53.9882C937.733 53.7162 937.625 53.456 937.435 53.2653C924.311 40.4267 903.606 40.4267 890.482 53.2653C890.291 53.4559 890.184 53.7159 890.182 53.9879C890.18 54.2599 890.285 54.5214 890.472 54.7146L894.073 58.4225C894.443 58.8035 895.046 58.8083 895.422 58.4331C900.423 53.5802 907.059 50.8742 913.959 50.8742ZM914.059 62.0682C917.849 62.068 921.505 63.5062 924.315 66.1035C924.695 66.4721 925.294 66.4641 925.664 66.0855L929.259 62.3775C929.449 62.1831 929.554 61.9192 929.551 61.645C929.548 61.3709 929.438 61.1093 929.245 60.9187C920.688 52.794 907.436 52.794 898.88 60.9187C898.686 61.1093 898.576 61.371 898.573 61.6453C898.571 61.9195 898.676 62.1833 898.866 62.3775L902.46 66.0855C902.831 66.4641 903.429 66.4721 903.809 66.1035C906.618 63.5079 910.27 62.0698 914.059 62.0682ZM921.369 69.3055C921.375 69.5805 921.269 69.8455 921.077 70.0381L914.858 76.4444C914.675 76.6326 914.427 76.7386 914.168 76.7386C913.908 76.7386 913.66 76.6326 913.477 76.4444L907.257 70.0381C907.065 69.8454 906.96 69.5802 906.965 69.3053C906.971 69.0303 907.088 68.77 907.288 68.5857C911.259 65.1568 917.076 65.1568 921.048 68.5857C921.247 68.7701 921.364 69.0306 921.369 69.3055Z" fill-rule="evenodd"/>\n'
      '  </g>\n'
      '  <circle cx="12.71" cy="61.85" r="1.6" fill="currentColor" fill-opacity="0.2"/>\n'
      '  <circle cx="18.51" cy="63.97" r="1.6" fill="currentColor" fill-opacity="0.2"/>\n'
      '  <circle cx="25.49" cy="63.97" r="1.6" fill="currentColor" fill-opacity="0.2"/>\n'
      '  <circle cx="31.29" cy="61.85" r="1.6" fill="currentColor" fill-opacity="0.2"/>\n'
      '</svg>',
);
