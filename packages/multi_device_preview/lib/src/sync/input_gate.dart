import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pointer events whose `device` is at or above this value were synthesized by
/// the input mirror. They are never mirrored again.
///
/// Real devices and Marionette (devices 1 to 3) stay well below it.
const int kSyntheticDeviceBase = 0x4D440000;

/// Pointer ids of synthesized events start here, far above the ids the engine
/// hands out.
const int kSyntheticPointerBase = 0x4D440000;

/// Tells apart pointer input coming from the operating system from events
/// injected in Dart (Marionette, the input mirror, tests).
///
/// It wraps `PlatformDispatcher.onPointerDataPacket` once, after the binding
/// installed its own handler, and raises [isHandlingPlatformInput] while a
/// packet is being dispatched. `GestureBinding` hit tests and dispatches the
/// packet synchronously, so the flag covers exactly those hit tests.
@internal
abstract final class PlatformInput {
  static int _depth = 0;
  static ui.PointerDataPacketCallback? _installed;

  /// Whether a pointer packet from the platform is being dispatched.
  static bool get isHandlingPlatformInput => _depth > 0;

  /// Whether mouse pointers are delivered as touches.
  ///
  /// The app is rendered as a phone, where a drag with the mouse should scroll
  /// like a finger does. `ScrollBehavior.dragDevices` leaves out the mouse, so
  /// without this only the trackpad and the wheel could scroll. Wheel and
  /// trackpad events keep their kind.
  static bool mouseAsTouch = true;

  /// Installs the hook on [dispatcher] if it is not installed yet.
  static void ensureInstalled(ui.PlatformDispatcher dispatcher) {
    final current = dispatcher.onPointerDataPacket;
    if (current != null && identical(current, _installed)) {
      return;
    }
    final original = current;
    void handle(ui.PointerDataPacket packet) {
      _depth++;
      try {
        original?.call(mouseAsTouch ? retargetMouseToTouch(packet) : packet);
      } finally {
        _depth--;
      }
    }

    _installed = handle;
    dispatcher.onPointerDataPacket = handle;
  }

  /// Runs [body] as if a platform packet were being dispatched.
  @visibleForTesting
  static T debugRunAsPlatformInput<T>(T Function() body) {
    _depth++;
    try {
      return body();
    } finally {
      _depth--;
    }
  }
}

/// Relabels mouse pointers in [packet] as touches and drops their hover
/// events, which a finger cannot produce. Signals (wheel, trackpad) and other
/// kinds pass through.
@internal
ui.PointerDataPacket retargetMouseToTouch(ui.PointerDataPacket packet) {
  var changed = false;
  final data = <ui.PointerData>[];
  for (final datum in packet.data) {
    if (datum.kind != ui.PointerDeviceKind.mouse ||
        datum.signalKind != null &&
            datum.signalKind != ui.PointerSignalKind.none) {
      data.add(datum);
      continue;
    }
    changed = true;
    if (datum.change == ui.PointerChange.hover) {
      continue;
    }
    data.add(_copyWithKind(datum, ui.PointerDeviceKind.touch));
  }
  return changed ? ui.PointerDataPacket(data: data) : packet;
}

ui.PointerData _copyWithKind(ui.PointerData datum, ui.PointerDeviceKind kind) {
  return ui.PointerData(
    viewId: datum.viewId,
    embedderId: datum.embedderId,
    timeStamp: datum.timeStamp,
    change: datum.change,
    kind: kind,
    signalKind: datum.signalKind,
    device: datum.device,
    pointerIdentifier: datum.pointerIdentifier,
    physicalX: datum.physicalX,
    physicalY: datum.physicalY,
    physicalDeltaX: datum.physicalDeltaX,
    physicalDeltaY: datum.physicalDeltaY,
    buttons: datum.buttons,
    obscured: datum.obscured,
    synthesized: datum.synthesized,
    pressure: datum.pressure,
    pressureMin: datum.pressureMin,
    pressureMax: datum.pressureMax,
    distance: datum.distance,
    distanceMax: datum.distanceMax,
    size: datum.size,
    radiusMajor: datum.radiusMajor,
    radiusMinor: datum.radiusMinor,
    radiusMin: datum.radiusMin,
    radiusMax: datum.radiusMax,
    orientation: datum.orientation,
    tilt: datum.tilt,
    platformData: datum.platformData,
    scrollDeltaX: datum.scrollDeltaX,
    scrollDeltaY: datum.scrollDeltaY,
    panX: datum.panX,
    panY: datum.panY,
    panDeltaX: datum.panDeltaX,
    panDeltaY: datum.panDeltaY,
    scale: datum.scale,
    rotation: datum.rotation,
    onRespond: ({bool allowPlatformDefault = false}) =>
        datum.respond(allowPlatformDefault: allowPlatformDefault),
  );
}

/// Blocks pointer input from the operating system to its subtree while
/// [closed] is true.
///
/// Only hit tests made while a platform packet is dispatched are blocked.
/// Hit tests from Marionette, from synthesized events and from the tool's own
/// element lookup still go through.
@internal
class InputGate extends SingleChildRenderObjectWidget {
  /// Creates a gate around [child].
  const InputGate({super.key, required this.closed, required super.child});

  /// Whether platform pointer input is blocked.
  final bool closed;

  @override
  RenderInputGate createRenderObject(BuildContext context) =>
      RenderInputGate(closed: closed);

  @override
  void updateRenderObject(BuildContext context, RenderInputGate renderObject) {
    renderObject.closed = closed;
  }
}

/// The render object behind [InputGate].
@internal
class RenderInputGate extends RenderProxyBox {
  /// Creates a gate.
  RenderInputGate({required this.closed});

  /// Whether platform pointer input is blocked.
  bool closed;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (closed && PlatformInput.isHandlingPlatformInput) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}

/// Whether [event] was synthesized by the input mirror.
@internal
bool isSyntheticPointerEvent(PointerEvent event) =>
    event.device >= kSyntheticDeviceBase;
