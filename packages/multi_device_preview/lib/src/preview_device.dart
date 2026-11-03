import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/widgets.dart';

/// One device shown side by side in the preview: a hardware preset, the text
/// scale the app is rendered with and the orientation the device is held in.
@immutable
class PreviewDevice {
  /// Creates a device entry from a `device_preview` [preset].
  const PreviewDevice({
    required this.preset,
    this.textScale = 1.0,
    this.orientation = Orientation.portrait,
  }) : assert(textScale > 0);

  /// The hardware preset (screen size, safe areas, frame artwork).
  final DevicePreset preset;

  /// The linear text scale factor applied through `MediaQuery.textScaler`.
  final double textScale;

  /// The orientation the device is held in.
  ///
  /// In [Orientation.landscape] the screen size is swapped, the preset's
  /// landscape safe areas are used and the frame artwork is rotated a quarter
  /// turn, as `device_preview` does for a rotated simulation.
  final Orientation orientation;

  /// The simulation resolved from [preset] in [orientation].
  DeviceSimulation get simulation => preset.resolve(orientation: orientation);

  /// The logical screen size the app is laid out in.
  Size get screenSize => switch (orientation) {
    Orientation.portrait => preset.portraitSize,
    Orientation.landscape => preset.portraitSize.flipped,
  };

  /// The space the frame artwork occupies outside the screen.
  ///
  /// `DevicePreviewFrame` is laid out at the screen size and paints the frame
  /// outside its own bounds, so the caller has to reserve this room.
  EdgeInsets get frameOutsets {
    if (preset.frame == null) {
      return EdgeInsets.zero;
    }
    final bounds = simulation.contentBounds;
    final size = screenSize;
    return EdgeInsets.fromLTRB(
      -bounds.left,
      -bounds.top,
      bounds.right - size.width,
      bounds.bottom - size.height,
    );
  }

  /// The total size of the device including its frame.
  Size get outerSize => frameOutsets.inflateSize(screenSize);

  /// Returns a copy with the given fields replaced.
  PreviewDevice copyWith({
    DevicePreset? preset,
    double? textScale,
    Orientation? orientation,
  }) => PreviewDevice(
    preset: preset ?? this.preset,
    textScale: textScale ?? this.textScale,
    orientation: orientation ?? this.orientation,
  );

  @override
  bool operator ==(Object other) =>
      other is PreviewDevice &&
      other.preset == preset &&
      other.textScale == textScale &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(preset, textScale, orientation);

  @override
  String toString() =>
      'PreviewDevice(${preset.id}, textScale: $textScale, '
      'orientation: ${orientation.name})';
}

/// Identifies a device instance handed to `appBuilder`.
@immutable
class DeviceSlot {
  /// Creates a slot for the device at [index].
  const DeviceSlot({required this.index, required this.device});

  /// The position of the device, from left to right, starting at 0.
  ///
  /// The device at index 0 is the input source while input mirroring is on.
  final int index;

  /// The device rendered in this slot.
  final PreviewDevice device;

  /// The key placed on this slot's screen, so tools such as Marionette can
  /// target a single device through `ancestor_keys`.
  ValueKey<String> get screenKey => screenKeyOf(index);

  /// The screen key of the device at [index].
  static ValueKey<String> screenKeyOf(int index) =>
      ValueKey<String>('multi_device_preview.screen.$index');

  @override
  bool operator ==(Object other) =>
      other is DeviceSlot && other.index == index && other.device == device;

  @override
  int get hashCode => Object.hash(index, device);

  @override
  String toString() => 'DeviceSlot($index, $device)';
}
