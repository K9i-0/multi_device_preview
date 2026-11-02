// The example driven by an AI agent through Marionette MCP:
//
//   flutter run -d macos -t marionette/main.dart
//
// Then connect marionette_mcp to the printed VM service URI. Besides the
// built-in tools, the agent gets multiDevicePreview.* tools (getState,
// setDevice, setSync, restart, saveScreenshot, panZoom, ...).
import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_example/app.dart';
import 'package:multi_device_preview_marionette/multi_device_preview_marionette.dart';

void main() {
  if (!kReleaseMode) {
    // Before runMultiDevicePreview, so the binding is Marionette's.
    MarionetteBinding.ensureInitialized(
      multiDevicePreviewMarionetteConfiguration,
    );
  }
  final controller = MultiDevicePreviewController(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
    ],
  );
  if (!kReleaseMode) {
    registerMultiDevicePreviewMarionetteExtensions(controller);
  }
  runMultiDevicePreview(
    controller: controller,
    appBuilder: (context, slot) => const ExampleApp(),
  );
}
