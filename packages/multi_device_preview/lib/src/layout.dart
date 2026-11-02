import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'preview_device.dart';

/// Where each device is placed when laid out in a single row, and how much the
/// row is scaled down to fit the window.
@internal
@immutable
class MultiDeviceLayout {
  const MultiDeviceLayout._({
    required this.deviceRects,
    required this.outerRects,
    required this.contentSize,
    required this.scale,
  });

  /// Lays [devices] out left to right, separated by [spacing] and surrounded
  /// by [padding], and computes the scale that fits the row in [available].
  ///
  /// Devices are aligned to the top. The row is never scaled up, only down,
  /// so the logical size inside each device stays unchanged.
  factory MultiDeviceLayout.compute({
    required List<PreviewDevice> devices,
    required Size available,
    double spacing = 32,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    final rects = <Rect>[];
    final outerRects = <Rect>[];
    var x = padding.left;
    var maxHeight = 0.0;
    for (final device in devices) {
      final outer = device.outerSize;
      final outsets = device.frameOutsets;
      rects.add(
        Rect.fromLTWH(
          x + outsets.left,
          padding.top + outsets.top,
          device.screenSize.width,
          device.screenSize.height,
        ),
      );
      outerRects.add(Rect.fromLTWH(x, padding.top, outer.width, outer.height));
      x += outer.width + spacing;
      maxHeight = math.max(maxHeight, outer.height);
    }
    if (devices.isNotEmpty) {
      x -= spacing;
    }
    final contentSize = Size(
      x + padding.right,
      padding.top + maxHeight + padding.bottom,
    );

    var scale = 1.0;
    if (contentSize.width > 0 &&
        contentSize.height > 0 &&
        available.isFinite &&
        !available.isEmpty) {
      scale = math.min(
        1.0,
        math.min(
          available.width / contentSize.width,
          available.height / contentSize.height,
        ),
      );
    }
    return MultiDeviceLayout._(
      deviceRects: List<Rect>.unmodifiable(rects),
      outerRects: List<Rect>.unmodifiable(outerRects),
      contentSize: contentSize,
      scale: scale,
    );
  }

  /// The screen rectangle of each device in unscaled content coordinates.
  ///
  /// The frame artwork extends outside these rectangles.
  final List<Rect> deviceRects;

  /// The rectangle of each device including its frame, in unscaled content
  /// coordinates.
  final List<Rect> outerRects;

  /// The unscaled size of the whole row, frames and padding included.
  final Size contentSize;

  /// The factor the row is scaled by to fit; at most 1.
  final double scale;
}
