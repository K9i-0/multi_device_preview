import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'chrome.dart';
import 'controller.dart';
import 'layout.dart';
import 'png.dart';
import 'preview_device.dart';
import 'sync/anchor.dart';
import 'sync/input_gate.dart';
import 'sync/input_mirror.dart';
import 'sync/sync_host.dart';
import 'sync/text_sync.dart';

/// Builds one instance of the app under preview for [slot].
///
/// It is called once per device (and again after a restart), so each device
/// gets its own widget tree and state, for example its own `ProviderScope`.
typedef MultiDeviceAppBuilder = Widget Function(
  BuildContext context,
  DeviceSlot slot,
);

/// How long [MultiDevicePreviewController.captureScreenshot] waits for a
/// frame.
const Duration kScreenshotFrameTimeout = Duration(seconds: 3);

/// Shows one instance of the app per device, side by side, scaled down to fit
/// the window, and mirrors input on the first device to the others.
///
/// The root is a [MaterialApp] built with [MaterialApp.builder] and no home,
/// so the tool creates no [Navigator] or [Overlay] above the devices: dialogs
/// opened with `rootNavigator: true` or `rootOverlay: true` stay inside the
/// device that opened them. The tool's own controls live in a separate layer
/// stacked over the devices.
///
/// Usually started through `runMultiDevicePreview`.
class MultiDevicePreview extends StatefulWidget {
  /// Creates a preview running the app from [appBuilder] on each device of
  /// [controller], or of [devices] when no controller is given.
  const MultiDevicePreview({
    super.key,
    required this.appBuilder,
    this.controller,
    this.devices = defaultPreviewDevices,
    this.anchorResolvers = const [],
    this.showToolbar = true,
    this.backgroundColor = const Color(0xFF1B1B1F),
  });

  /// Builds the app instance for each device.
  final MultiDeviceAppBuilder appBuilder;

  /// Controls the devices and input mirroring. When null, the preview creates
  /// its own controller with [devices].
  final MultiDevicePreviewController? controller;

  /// The devices shown when [controller] is null. Ignored otherwise.
  final List<PreviewDevice> devices;

  /// Extra ways to recognize the same element across devices, tried before
  /// the built-in ones (keys, semantics, images, text, input fields).
  final List<AnchorResolver> anchorResolvers;

  /// Whether the toolbar, the device labels and the settings sheet are shown.
  final bool showToolbar;

  /// The color behind the devices.
  final Color backgroundColor;

  @override
  State<MultiDevicePreview> createState() => _MultiDevicePreviewState();
}

class _MultiDevicePreviewState extends State<MultiDevicePreview>
    implements SyncHost, PreviewScreenshotter {
  MultiDevicePreviewController? _ownController;
  late MultiDevicePreviewController _controller;
  late final InputMirror _mirror = InputMirror(this);
  late final TextSync _textSync = TextSync(this);

  final GlobalKey _stageKey = GlobalKey(
    debugLabel: 'multi_device_preview.stage',
  );
  final Map<int, GlobalKey> _appKeys = {};
  final Map<int, GlobalKey> _boundaryKeys = {};
  final Map<int, GlobalKey> _screenBoundaryKeys = {};
  final Map<int, ValueNotifier<bool>> _bareScreens = {};
  final Map<int, GlobalKey> _probeKeys = {};
  final Map<int, ValueNotifier<SystemUiOverlayStyle?>> _overlayStyles = {};

  ChromeSheet? _sheet;
  bool _styleLoopScheduled = false;

  @override
  void initState() {
    super.initState();
    PlatformInput.ensureInstalled(WidgetsBinding.instance.platformDispatcher);
    _attach(widget.controller ?? (_ownController = _createController()));
    _scheduleStyleUpdate();
  }

  MultiDevicePreviewController _createController() =>
      MultiDevicePreviewController(devices: widget.devices);

  void _attach(MultiDevicePreviewController controller) {
    _controller = controller
      ..addListener(_handleControllerChanged)
      ..screenshotter = this;
    _handleControllerChanged();
  }

  void _detach() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..screenshotter = null;
  }

  @override
  void didUpdateWidget(covariant MultiDevicePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach();
      _ownController?.dispose();
      _ownController = null;
      _attach(widget.controller ?? (_ownController = _createController()));
    }
  }

  void _handleControllerChanged() {
    _textSync.running =
        _controller.syncEnabled && _controller.devices.length > 1;
    final ids = {
      for (var i = 0; i < _controller.devices.length; i++) _controller.idAt(i),
    };
    for (final id in _overlayStyles.keys.toList()) {
      if (!ids.contains(id)) {
        _appKeys.remove(id);
        _boundaryKeys.remove(id);
        _screenBoundaryKeys.remove(id);
        _probeKeys.remove(id);
        final notifier = _overlayStyles.remove(id)!;
        final bare = _bareScreens.remove(id)!;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifier.dispose();
          bare.dispose();
        });
      }
    }
    for (final id in ids) {
      _overlayStyles.putIfAbsent(id, () => ValueNotifier(null));
      _bareScreens.putIfAbsent(id, () => ValueNotifier(false));
    }
    if (_sheet case EditDeviceSheet(:final index)
        when index >= _controller.devices.length) {
      _sheet = null;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _detach();
    _ownController?.dispose();
    _mirror.dispose();
    _textSync.dispose();
    for (final notifier in _overlayStyles.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  // SyncHost ------------------------------------------------------------------

  @override
  int get deviceCount => _controller.devices.length;

  @override
  bool get syncEnabled => _controller.syncEnabled;

  @override
  int idOf(int index) => _controller.idAt(index);

  @override
  int? indexOfId(int id) {
    for (var i = 0; i < deviceCount; i++) {
      if (_controller.idAt(i) == id) {
        return i;
      }
    }
    return null;
  }

  @override
  Element? appElementOf(int device) {
    if (device < 0 || device >= deviceCount) {
      return null;
    }
    return _appKeys[_controller.idAt(device)]?.currentContext as Element?;
  }

  @override
  AnchorIndex? anchorsOf(int device) {
    final element = appElementOf(device);
    final root = element?.renderObject;
    if (element == null || root is! RenderBox || !root.hasSize) {
      return null;
    }
    return AnchorIndex.collect(
      element,
      root,
      resolvers: [...widget.anchorResolvers, ...builtInAnchorResolvers],
    );
  }

  @override
  int? deviceOf(BuildContext context) {
    final roots = <Element, int>{
      for (var i = 0; i < deviceCount; i++) ?appElementOf(i): i,
    };
    if (roots[context] case final index?) {
      return index;
    }
    int? found;
    context.visitAncestorElements((ancestor) {
      found = roots[ancestor];
      return found == null;
    });
    return found;
  }

  @override
  void markOutOfSync(int device) => _controller.markOutOfSync(device);

  // Screenshots ---------------------------------------------------------------

  Future<void> _nextFrame() async {
    SchedulerBinding.instance.scheduleFrame();
    await SchedulerBinding.instance.endOfFrame.timeout(
      kScreenshotFrameTimeout,
      onTimeout: () => throw TimeoutException(
        'No frame was produced. On macOS, the window stops rendering while it '
        'is hidden behind other windows; bring it to the front and retry.',
        kScreenshotFrameTimeout,
      ),
    );
  }

  @override
  Future<Uint8List> capture({int? device, double pixelRatio = 1.0}) async {
    await _nextFrame();
    final key = device == null
        ? _stageKey
        : _boundaryKeys[_controller.idAt(device)];
    final boundary = key?.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('The preview is not laid out yet.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Future<Uint8List> captureScreen(int device) async {
    final id = _controller.idAt(device);
    final preset = _controller.devices[device].preset;
    final bare = _bareScreens[id]!;
    // Without the frame, the screen is neither clipped to its rounded outline
    // nor cut by the camera, like a screenshot taken on the device.
    bare.value = true;
    final ui.Image image;
    try {
      await _nextFrame();
      final boundary = _screenBoundaryKeys[id]?.currentContext
          ?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('The preview is not laid out yet.');
      }
      image = await boundary.toImage(pixelRatio: preset.devicePixelRatio);
    } finally {
      if (_bareScreens[id] == bare) {
        bare.value = false;
      }
    }
    try {
      return await _encodeOpaque(image);
    } finally {
      image.dispose();
    }
  }

  // Composites [image] over black and encodes it without an alpha channel.
  static Future<Uint8List> _encodeOpaque(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final bounds =
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble());
    Canvas(recorder)
      ..drawRect(bounds, Paint()..color = const Color(0xFF000000))
      ..drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final flat = await picture.toImage(image.width, image.height);
    picture.dispose();
    try {
      final bytes = await flat.toByteData(format: ui.ImageByteFormat.rawRgba);
      return encodeOpaquePng(
        bytes!.buffer.asUint8List(),
        flat.width,
        flat.height,
      );
    } finally {
      flat.dispose();
    }
  }

  // Status bar style ----------------------------------------------------------

  void _scheduleStyleUpdate() {
    if (_styleLoopScheduled) {
      return;
    }
    _styleLoopScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _styleLoopScheduled = false;
      if (!mounted) {
        return;
      }
      for (final MapEntry(key: id, value: notifier) in _overlayStyles.entries) {
        final probe = _probeKeys[id]?.currentContext?.findRenderObject();
        if (probe is RenderOverlayStyleProbe) {
          notifier.value = probe.overlayStyle();
        }
      }
      _scheduleStyleUpdate();
    }, debugLabel: 'multi_device_preview.overlayStyle');
  }

  // Build ---------------------------------------------------------------------

  void _openSheet(ChromeSheet sheet) => setState(() => _sheet = sheet);

  void _closeSheet() => setState(() => _sheet = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'multi_device_preview',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF6E7BF2),
      ),
      builder: (context, _) => LayoutBuilder(builder: _buildStage),
    );
  }

  Widget _buildStage(BuildContext context, BoxConstraints constraints) {
    final devices = _controller.devices;
    final size = constraints.biggest;
    final top = widget.showToolbar ? kToolbarExtent + kLabelExtent : 0.0;
    final layout = MultiDeviceLayout.compute(
      devices: devices,
      available: Size(size.width, math.max(0, size.height - top)),
      padding: EdgeInsets.fromLTRB(24, widget.showToolbar ? 0 : 24, 24, 24),
    );
    final scaled = layout.contentSize * layout.scale;
    final origin = Offset((size.width - scaled.width) / 2, top);

    final stage = Positioned(
      left: origin.dx,
      top: origin.dy,
      width: scaled.width,
      height: scaled.height,
      child: FittedBox(
        fit: BoxFit.fill,
        child: RepaintBoundary(
          key: _stageKey,
          child: ColoredBox(
            color: widget.backgroundColor,
            child: SizedBox.fromSize(
              size: layout.contentSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < devices.length; i++)
                    Positioned.fromRect(
                      key: ValueKey<int>(_controller.idAt(i)),
                      rect: layout.outerRects[i],
                      child: _buildDevice(i, devices),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          stage,
          if (widget.showToolbar)
            Positioned.fill(
              child: Overlay.wrap(
                child: PreviewChrome(
                  controller: _controller,
                  deviceRects: [
                    for (final rect in layout.outerRects)
                      Rect.fromLTWH(
                        origin.dx + rect.left * layout.scale,
                        origin.dy + rect.top * layout.scale,
                        rect.width * layout.scale,
                        rect.height * layout.scale,
                      ),
                  ],
                  sheet: _sheet,
                  onOpenSheet: _openSheet,
                  onCloseSheet: _closeSheet,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDevice(int index, List<PreviewDevice> devices) {
    final id = _controller.idAt(index);
    return _DeviceScreen(
      key: ValueKey<int>(id),
      slot: DeviceSlot(index: index, device: devices[index]),
      generation: _controller.generation,
      appBuilder: widget.appBuilder,
      appKey: _appKeys.putIfAbsent(id, GlobalKey.new),
      boundaryKey: _boundaryKeys.putIfAbsent(id, GlobalKey.new),
      screenBoundaryKey: _screenBoundaryKeys.putIfAbsent(id, GlobalKey.new),
      bareScreen: _bareScreens[id]!,
      probeKey: _probeKeys.putIfAbsent(id, GlobalKey.new),
      overlayStyle: _overlayStyles[id]!,
      gateClosed: index > 0 && _controller.syncEnabled && devices.length > 1,
      onPointerEvent: _mirror.handleSourceEvent,
    );
  }
}

class _DeviceScreen extends StatefulWidget {
  const _DeviceScreen({
    super.key,
    required this.slot,
    required this.generation,
    required this.appBuilder,
    required this.appKey,
    required this.boundaryKey,
    required this.screenBoundaryKey,
    required this.bareScreen,
    required this.probeKey,
    required this.overlayStyle,
    required this.gateClosed,
    required this.onPointerEvent,
  });

  final DeviceSlot slot;
  final int generation;
  final MultiDeviceAppBuilder appBuilder;
  final GlobalKey appKey;
  final GlobalKey boundaryKey;
  final GlobalKey screenBoundaryKey;
  final ValueListenable<bool> bareScreen;
  final GlobalKey probeKey;
  final ValueListenable<SystemUiOverlayStyle?> overlayStyle;
  final bool gateClosed;
  final ValueChanged<PointerEvent> onPointerEvent;

  @override
  State<_DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<_DeviceScreen> {
  late final ValueNotifier<DeviceSimulation?> _simulation = ValueNotifier(
    _resolveSimulation(),
  );

  @override
  void initState() {
    super.initState();
    widget.bareScreen.addListener(_updateSimulation);
  }

  // While the screen is captured bare, the frame (and with it the screen clip)
  // is dropped; the system UI is still painted.
  DeviceSimulation _resolveSimulation() {
    final simulation = widget.slot.device.simulation;
    return widget.bareScreen.value
        ? simulation.copyWith(frame: null)
        : simulation;
  }

  void _updateSimulation() => _simulation.value = _resolveSimulation();

  Widget? _app;
  int? _appGeneration;

  @override
  void didUpdateWidget(covariant _DeviceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bareScreen != widget.bareScreen) {
      oldWidget.bareScreen.removeListener(_updateSimulation);
      widget.bareScreen.addListener(_updateSimulation);
      _updateSimulation();
    } else if (oldWidget.slot.device.preset != widget.slot.device.preset) {
      _updateSimulation();
    }
  }

  @override
  void dispose() {
    widget.bareScreen.removeListener(_updateSimulation);
    _simulation.dispose();
    super.dispose();
  }

  void _handlePointer(PointerEvent event) {
    if (widget.slot.index == 0) {
      widget.onPointerEvent(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The app is built once per generation and reused, so switching the
    // preset or the text scale keeps its state, while a restart replaces it.
    if (_appGeneration != widget.generation) {
      _appGeneration = widget.generation;
      _app = KeyedSubtree(
        // A global key, so the app keeps its state when the device moves to
        // another index (and the screen key above it changes).
        key: GlobalKey(debugLabel: 'multi_device_preview.app'),
        child: Builder(
          builder: (context) => widget.appBuilder(context, widget.slot),
        ),
      );
    }
    final device = widget.slot.device;
    final simulation = _simulation.value!;
    final base = MediaQuery.of(context);
    return RepaintBoundary(
      key: widget.boundaryKey,
      child: Padding(
        padding: device.frameOutsets,
        child: RepaintBoundary(
          key: widget.screenBoundaryKey,
          child: DevicePreviewFrame(
            simulation: _simulation,
            overlayStyle: widget.overlayStyle,
            child: MediaQuery(
              data: base.copyWith(
                size: device.screenSize,
                padding: simulation.padding ?? EdgeInsets.zero,
                viewPadding:
                    simulation.viewPadding ??
                    simulation.padding ??
                    EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
                systemGestureInsets:
                    simulation.systemGestureInsets ?? EdgeInsets.zero,
                textScaler: TextScaler.linear(device.textScale),
                displayFeatures: const [],
              ),
              child: InputGate(
                closed: widget.gateClosed,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _handlePointer,
                  onPointerMove: _handlePointer,
                  onPointerUp: _handlePointer,
                  onPointerCancel: _handlePointer,
                  onPointerSignal: _handlePointer,
                  onPointerPanZoomStart: _handlePointer,
                  onPointerPanZoomUpdate: _handlePointer,
                  onPointerPanZoomEnd: _handlePointer,
                  child: OverlayStyleProbe(
                    key: widget.probeKey,
                    child: SizedBox.expand(
                      key: widget.appKey,
                      child: KeyedSubtree(
                        key: widget.slot.screenKey,
                        child: _app!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DeviceSlot>('slot', widget.slot));
  }
}

/// Reads the `SystemUiOverlayStyle` the app declares (through
/// `AnnotatedRegion`, as `AppBar` does) at the top and bottom of the screen,
/// to tint the simulated status bar like the real one.
@internal
class OverlayStyleProbe extends SingleChildRenderObjectWidget {
  /// Creates a probe around [child].
  const OverlayStyleProbe({super.key, required super.child});

  @override
  RenderOverlayStyleProbe createRenderObject(BuildContext context) =>
      RenderOverlayStyleProbe();
}

/// The render object behind [OverlayStyleProbe].
@internal
class RenderOverlayStyleProbe extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;

  /// The style at the top of the screen, with the navigation bar fields taken
  /// from the bottom, as `RenderView` combines them.
  SystemUiOverlayStyle? overlayStyle() {
    final layer = this.layer;
    if (layer is! OffsetLayer || !hasSize) {
      return null;
    }
    final top = layer.find<SystemUiOverlayStyle>(
      layer.offset + Offset(size.width / 2, 1),
    );
    final bottom = layer.find<SystemUiOverlayStyle>(
      layer.offset + Offset(size.width / 2, size.height - 1),
    );
    if (top == null) {
      return bottom;
    }
    if (bottom == null) {
      return top;
    }
    return top.copyWith(
      systemNavigationBarColor: bottom.systemNavigationBarColor,
      systemNavigationBarDividerColor: bottom.systemNavigationBarDividerColor,
      systemNavigationBarIconBrightness:
          bottom.systemNavigationBarIconBrightness,
      systemNavigationBarContrastEnforced:
          bottom.systemNavigationBarContrastEnforced,
    );
  }
}
