import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'multi_device_preview.dart';
import 'preview_device.dart';

/// The devices shown when none are given to [runMultiDevicePreview].
const List<PreviewDevice> defaultPreviewDevices = [
  PreviewDevice(preset: DevicePresets.iPhoneSe3),
  PreviewDevice(preset: DevicePresets.iPhone17),
  PreviewDevice(preset: DevicePresets.iPhone17, textScale: 1.5),
];

/// Runs the app built by [appBuilder] on each of [devices], side by side.
///
/// Call it from a dedicated entry point (for example
/// `multi_device_preview/main.dart`) and launch it on macOS:
///
/// ```sh
/// flutter run -d macos -t multi_device_preview/main.dart
/// ```
///
/// In debug mode every device is rendered as iOS. The override is not applied
/// in profile mode, where `debugDefaultTargetPlatformOverride` throws.
void runMultiDevicePreview({
  required MultiDeviceAppBuilder appBuilder,
  List<PreviewDevice> devices = defaultPreviewDevices,
}) {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  }
  runApp(MultiDevicePreview(devices: devices, appBuilder: appBuilder));
}
