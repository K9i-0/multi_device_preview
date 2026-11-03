import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';

import 'presets.dart';
import 'preview_device.dart';

/// The devices shown when no devices are given.
const List<PreviewDevice> defaultPreviewDevices = [
  PreviewDevice(preset: DevicePresets.iPhoneSe3),
  PreviewDevice(preset: DevicePresets.iPhone17),
  PreviewDevice(preset: DevicePresets.iPhone17, textScale: 1.5),
];

/// Captures images of the preview. Implemented by the preview widget.
@internal
abstract interface class PreviewScreenshotter {
  /// Renders the whole preview, or only the device at [device], as PNG bytes.
  Future<Uint8List> capture({int? device, double pixelRatio});

  /// Renders only the screen of the device at [device], without its frame,
  /// at its device pixel ratio, as an opaque PNG.
  Future<Uint8List> captureScreen(int device);
}

/// Holds the configuration of a `MultiDevicePreview`: which devices are shown,
/// whether input is mirrored, and which devices fell out of sync.
///
/// Listen to it to react to changes. Changes made through it are reflected by
/// the preview immediately, and the app state of each device is kept unless
/// [restart] is called.
class MultiDevicePreviewController extends ChangeNotifier {
  /// Creates a controller showing [devices], with input mirroring set by
  /// [syncEnabled].
  MultiDevicePreviewController({
    List<PreviewDevice> devices = defaultPreviewDevices,
    this._syncEnabled = true,
  }) : assert(devices.isNotEmpty, 'At least one device is required.'),
       _entries = [for (final device in devices) _Entry(_nextId++, device)];

  static int _nextId = 0;

  final List<_Entry> _entries;

  /// The devices, from left to right.
  ///
  /// The device at index 0 is the input source while [syncEnabled] is true.
  List<PreviewDevice> get devices =>
      List<PreviewDevice>.unmodifiable(_entries.map((e) => e.device));

  /// A stable identifier for the device at [index].
  ///
  /// It survives [setDevice] and the removal of other devices, so the app
  /// instance of a device is kept while it moves.
  @internal
  int idAt(int index) => _entries[index].id;

  /// Replaces the device at [index], keeping its app state.
  void setDevice(int index, PreviewDevice device) {
    RangeError.checkValidIndex(index, _entries, 'index');
    if (_entries[index].device == device) {
      return;
    }
    _entries[index] = _Entry(_entries[index].id, device);
    notifyListeners();
  }

  /// Appends [device] to the right end.
  void addDevice(PreviewDevice device) {
    _entries.add(_Entry(_nextId++, device));
    notifyListeners();
  }

  /// Removes the device at [index]. The last remaining device cannot be
  /// removed.
  void removeDevice(int index) {
    RangeError.checkValidIndex(index, _entries, 'index');
    if (_entries.length == 1) {
      throw StateError('The last device cannot be removed.');
    }
    final removed = _entries.removeAt(index);
    _outOfSync.remove(removed.id);
    notifyListeners();
  }

  bool _syncEnabled;

  /// Whether input on the first device is mirrored to the other devices.
  ///
  /// While it is true, only the first device accepts pointer input from the
  /// user. Gestures that already started are completed after it is turned
  /// off.
  bool get syncEnabled => _syncEnabled;
  set syncEnabled(bool value) {
    if (_syncEnabled == value) {
      return;
    }
    _syncEnabled = value;
    notifyListeners();
  }

  int _generation = 0;

  /// Incremented by [restart]; every app instance is rebuilt from scratch when
  /// it changes.
  int get generation => _generation;

  /// Rebuilds the app on every device from scratch and clears the
  /// out-of-sync marks.
  ///
  /// Use it to bring devices back in line after they drifted apart. State
  /// persisted outside the widget tree (files, SharedPreferences, globals)
  /// is not reset.
  void restart() {
    _generation++;
    _outOfSync.clear();
    notifyListeners();
  }

  final Set<int> _outOfSync = {};

  /// The indices of devices that missed a mirrored gesture since the last
  /// [restart].
  Set<int> get outOfSyncDevices => {
    for (var i = 0; i < _entries.length; i++)
      if (_outOfSync.contains(_entries[i].id)) i,
  };

  /// Marks the device at [index] as out of sync.
  @internal
  void markOutOfSync(int index) {
    if (index < 0 || index >= _entries.length) {
      return;
    }
    if (_outOfSync.add(_entries[index].id)) {
      notifyListeners();
    }
  }

  /// Clears the out-of-sync mark of every device without restarting.
  void clearOutOfSync() {
    if (_outOfSync.isEmpty) {
      return;
    }
    _outOfSync.clear();
    notifyListeners();
  }

  PreviewScreenshotter? _screenshotter;

  /// Connects the preview widget that renders this controller.
  @internal
  set screenshotter(PreviewScreenshotter? value) => _screenshotter = value;

  /// Renders the whole preview, or only the device at [device] including its
  /// frame, as PNG bytes.
  ///
  /// Waits for the next frame so the result includes the latest input. Throws
  /// a [StateError] when no preview is attached and a `TimeoutException` when
  /// no frame is produced in time — on macOS this happens while the window is
  /// hidden behind other windows.
  Future<Uint8List> captureScreenshot({int? device, double pixelRatio = 1.0}) {
    final screenshotter = _screenshotter;
    if (screenshotter == null) {
      throw StateError('No MultiDevicePreview is attached to the controller.');
    }
    if (device != null) {
      RangeError.checkValidIndex(device, _entries, 'device');
    }
    return screenshotter.capture(device: device, pixelRatio: pixelRatio);
  }

  /// Renders only the screen of the device at [device] as PNG bytes, the way
  /// the device itself takes a screenshot: no frame and no rounded corners,
  /// at the preset's device pixel ratio, without an alpha channel.
  ///
  /// The result has the pixel size App Store Connect expects for that
  /// device, for example 1398×2034 for [MultiDevicePresets.iPhoneDuo]. The
  /// simulated status bar and home indicator are kept. The frame of that
  /// device disappears for one frame while it is captured.
  ///
  /// Throws like [captureScreenshot].
  Future<Uint8List> captureScreen(int device) {
    final screenshotter = _screenshotter;
    if (screenshotter == null) {
      throw StateError('No MultiDevicePreview is attached to the controller.');
    }
    RangeError.checkValidIndex(device, _entries, 'device');
    return screenshotter.captureScreen(device);
  }
}

@immutable
class _Entry {
  const _Entry(this.id, this.device);

  final int id;
  final PreviewDevice device;
}
