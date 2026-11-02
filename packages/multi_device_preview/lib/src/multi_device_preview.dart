import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'layout.dart';
import 'preview_device.dart';

/// Builds one instance of the app under preview for [slot].
///
/// It is called once per device, so each device gets its own widget tree and
/// state (for example its own `ProviderScope`).
typedef MultiDeviceAppBuilder = Widget Function(
  BuildContext context,
  DeviceSlot slot,
);

/// Shows one instance of the app per device, side by side, scaled down to fit
/// the window.
///
/// The root is a [MaterialApp] built with [MaterialApp.builder] and no home,
/// so the tool creates neither a [Navigator] nor an [Overlay] above the
/// devices: dialogs opened with `rootNavigator: true` or `rootOverlay: true`
/// stay inside the device that opened them.
class MultiDevicePreview extends StatefulWidget {
  /// Creates a preview of [devices], each running the app from [appBuilder].
  const MultiDevicePreview({
    super.key,
    required this.devices,
    required this.appBuilder,
    this.backgroundColor = const Color(0xFF1E1E22),
  });

  /// The devices to show, from left to right.
  final List<PreviewDevice> devices;

  /// Builds the app instance for each device.
  final MultiDeviceAppBuilder appBuilder;

  /// The color behind the devices.
  final Color backgroundColor;

  @override
  State<MultiDevicePreview> createState() => _MultiDevicePreviewState();
}

class _MultiDevicePreviewState extends State<MultiDevicePreview> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'multi_device_preview',
      builder: (context, _) => ColoredBox(
        color: widget.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = MultiDeviceLayout.compute(
              devices: widget.devices,
              available: constraints.biggest,
            );
            return Center(
              child: SizedBox.fromSize(
                size: layout.contentSize * layout.scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(
                    size: layout.contentSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < widget.devices.length; i++)
                          Positioned.fromRect(
                            rect: layout.deviceRects[i],
                            child: _DeviceScreen(
                              // Keyed by position so the app state survives
                              // switching the preset or text scale.
                              key: ValueKey<int>(i),
                              slot: DeviceSlot(
                                index: i,
                                device: widget.devices[i],
                              ),
                              appBuilder: widget.appBuilder,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeviceScreen extends StatefulWidget {
  const _DeviceScreen({
    super.key,
    required this.slot,
    required this.appBuilder,
  });

  final DeviceSlot slot;
  final MultiDeviceAppBuilder appBuilder;

  @override
  State<_DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<_DeviceScreen> {
  late final ValueNotifier<DeviceSimulation?> _simulation =
      ValueNotifier<DeviceSimulation?>(widget.slot.device.simulation);

  // Built once and reused, so changing the device does not rebuild the app
  // from scratch.
  late final Widget _app = Builder(
    builder: (context) => widget.appBuilder(context, widget.slot),
  );

  @override
  void didUpdateWidget(covariant _DeviceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.device.preset != widget.slot.device.preset) {
      _simulation.value = widget.slot.device.simulation;
    }
  }

  @override
  void dispose() {
    _simulation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.slot.device;
    final simulation = _simulation.value!;
    final base = MediaQuery.of(context);
    return DevicePreviewFrame(
      simulation: _simulation,
      child: MediaQuery(
        data: base.copyWith(
          size: device.screenSize,
          padding: simulation.padding ?? EdgeInsets.zero,
          viewPadding:
              simulation.viewPadding ?? simulation.padding ?? EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
          systemGestureInsets:
              simulation.systemGestureInsets ?? EdgeInsets.zero,
          textScaler: TextScaler.linear(device.textScale),
          displayFeatures: const [],
        ),
        child: KeyedSubtree(key: widget.slot.screenKey, child: _app),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DeviceSlot>('slot', widget.slot));
  }
}
