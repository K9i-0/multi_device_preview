import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'commands.dart';
import 'controller.dart';
import 'multi_device_preview.dart';
import 'preview_device.dart';
import 'sync/anchor.dart';
import 'sync/input_gate.dart';

/// Runs the app built by [appBuilder] on each of [devices], side by side.
///
/// Call it from a dedicated entry point (for example
/// `multi_device_preview/main.dart`) and launch it on macOS:
///
/// ```sh
/// flutter run -d macos -t multi_device_preview/main.dart
/// ```
///
/// - [controller] controls the devices and input mirroring from code; when it
///   is null one is created with [devices].
/// - [wrapper] wraps the whole preview, for things that must exist once
///   above all devices (for example slang's `TranslationProvider`, which
///   holds a global key).
/// - [targetPlatform] is the platform every device is rendered as, in debug
///   mode only: assigning `debugDefaultTargetPlatformOverride` throws in
///   profile mode. Pass null to keep the host's.
/// - [mouseAsTouch] delivers mouse pointers as touches, so dragging with the
///   mouse scrolls like a finger. Wheel and trackpad keep their kind.
/// - [anchorResolvers] add ways to recognize the same element across devices.
/// - [statusBarTime] is the time shown in every simulated status bar.
/// - [registerServiceExtensions] exposes [previewCommands] as VM service
///   extensions (`ext.multi_device_preview.*`), outside release mode.
///
/// When a binding was initialized before (for example `MarionetteBinding`),
/// it is kept.
void runMultiDevicePreview({
  required MultiDeviceAppBuilder appBuilder,
  List<PreviewDevice> devices = defaultPreviewDevices,
  MultiDevicePreviewController? controller,
  Widget Function(Widget preview)? wrapper,
  TargetPlatform? targetPlatform = TargetPlatform.iOS,
  bool mouseAsTouch = true,
  List<AnchorResolver> anchorResolvers = const [],
  bool registerServiceExtensions = true,
  String statusBarTime = '9:41',
}) {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode && targetPlatform != null) {
    debugDefaultTargetPlatformOverride = targetPlatform;
  }
  PlatformInput.mouseAsTouch = mouseAsTouch;
  final effectiveController =
      controller ?? MultiDevicePreviewController(devices: devices);
  if (registerServiceExtensions) {
    registerPreviewServiceExtensions(effectiveController);
  }
  final Widget preview = MultiDevicePreview(
    appBuilder: appBuilder,
    controller: effectiveController,
    anchorResolvers: anchorResolvers,
    statusBarTime: statusBarTime,
  );
  runApp(wrapper == null ? preview : wrapper(preview));
}
