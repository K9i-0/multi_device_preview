import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'input_gate.dart';
import 'position_mapping.dart';
import 'sync_host.dart';

/// How long a device waits for the element a gesture targets to appear, for
/// example while the page is still loading after start-up.
const Duration kMirrorResolveTimeout = Duration(seconds: 5);

const Duration _pollInterval = Duration(milliseconds: 50);

/// Sends pointer input on the source device (device 0) to every other device.
///
/// Each gesture, from pointer down to up, is mapped when it starts
/// ([capturePoint]) and queued per device. A device waits until the target
/// element appears, scrolls it into view when needed, and replays the
/// gesture keeping the original intervals between events, so long presses
/// and flings behave the same.
///
/// Taps that cannot be located precisely are not sent: on a device of another
/// height they could press a different element. Drags and scrolls are sent
/// anyway, since landing in the same scroll view is enough.
@internal
class InputMirror {
  /// Creates a mirror for the devices of [host].
  InputMirror(this.host) {
    FocusManager.instance.addListener(_trackSourceFocus);
  }

  /// The devices.
  final SyncHost host;

  final Map<int, _Gesture> _active = {};
  final Map<int, _TargetQueue> _queues = {};

  /// The node most recently focused on the source device.
  FocusNode? _sourceFocus;
  bool _disposed = false;
  static int _nextPointer = kSyntheticPointerBase;

  /// Handles [event] received on the source device.
  void handleSourceEvent(PointerEvent event) {
    if (_disposed || isSyntheticPointerEvent(event)) {
      return;
    }
    switch (event) {
      case PointerDownEvent() || PointerPanZoomStartEvent():
        if (!host.syncEnabled || host.deviceCount < 2) {
          return;
        }
        final gesture = _start(
          event,
          isScroll: event is PointerPanZoomStartEvent,
        );
        if (gesture != null) {
          _active[event.pointer] = gesture;
        }
      case PointerScrollEvent():
        if (!host.syncEnabled || host.deviceCount < 2) {
          return;
        }
        _start(event, isScroll: true)?.end();
      case PointerMoveEvent() || PointerPanZoomUpdateEvent():
        _active[event.pointer]?.add(event);
      case PointerUpEvent() || PointerCancelEvent() || PointerPanZoomEndEvent():
        _active.remove(event.pointer)
          ?..add(event)
          ..end();
      default:
        break;
    }
  }

  _Gesture? _start(PointerEvent first, {required bool isScroll}) {
    final anchors = host.anchorsOf(0);
    if (anchors == null) {
      return null;
    }
    final gesture = _Gesture(
      capturePoint(anchors, first.position),
      first,
      isScroll: isScroll,
    );
    for (var device = 1; device < host.deviceCount; device++) {
      // Queued by id: indices shift when a device is added or removed while
      // gestures are pending.
      final id = host.idOf(device);
      _queues.putIfAbsent(id, _TargetQueue.new).add(() => _send(id, gesture));
    }
    return gesture;
  }

  Future<void> _send(int id, _Gesture gesture) async {
    // Never re-enter GestureBinding while it dispatches the source event.
    await _afterSource();

    while (!gesture.capture.precise && !gesture.moved && !gesture.ended) {
      await gesture.changed;
    }
    if (_disposed) {
      return;
    }
    if (!gesture.capture.precise && !gesture.moved) {
      _markOutOfSync(id);
      return;
    }

    final target = await _resolve(id, gesture.capture);
    if (target == null) {
      if (!_disposed) {
        _markOutOfSync(id);
      }
      return;
    }

    final shift = target - gesture.first.position;
    final pointer = _nextPointer++;
    final syntheticDevice = kSyntheticDeviceBase + id % 0x10000;
    final clock = Stopwatch()..start();
    final start = gesture.first.timeStamp;
    var sent = 0;
    while (true) {
      if (sent < gesture.events.length) {
        final event = gesture.events[sent];
        final wait = event.timeStamp - start - clock.elapsed;
        if (wait > Duration.zero) {
          await Future<void>.delayed(wait);
        }
        final synthetic = synthesizePointerEvent(
          event,
          pointer: pointer,
          device: syntheticDevice,
          position: event.position + shift,
        );
        if (synthetic != null) {
          GestureBinding.instance.handlePointerEvent(synthetic);
          // Events queued while waiting are replayed in a burst. Let the
          // gesture arena resolve between them (it does so in a microtask),
          // as it would between events coming from the platform.
          await Future<void>.microtask(() {});
        }
        sent++;
      } else if (gesture.ended) {
        break;
      } else {
        await gesture.changed;
        await _afterSource();
      }
    }

    // Let focus changes caused by the synthetic tap (scheduled as microtasks)
    // settle, then give focus back to the source device so the keyboard keeps
    // typing there. Other devices receive the text through TextSync.
    await Future<void>.delayed(Duration.zero);
    _restoreFocus(id);
  }

  void _markOutOfSync(int id) {
    if (host.indexOfId(id) case final index?) {
      host.markOutOfSync(index);
    }
  }

  /// Waits until the source device has handled the latest event, including
  /// the focus changes it scheduled as microtasks. Otherwise a focus request
  /// from a mirrored tap could override the source's in the same batch.
  static Future<void> _afterSource() => Future<void>.delayed(Duration.zero);

  Future<Offset?> _resolve(int id, CapturedPoint capture) async {
    // Counted in polls rather than measured, so fake clocks in tests work.
    var remaining =
        kMirrorResolveTimeout.inMicroseconds ~/ _pollInterval.inMicroseconds;
    var revealed = false;
    while (!_disposed) {
      final device = host.indexOfId(id);
      if (device == null) {
        return null;
      }
      final anchors = host.anchorsOf(device);
      if (anchors != null) {
        switch (resolvePoint(anchors, capture)) {
          case FoundPoint(:final globalPosition):
            return globalPosition;
          case HiddenPoint(:final element) when !revealed:
            revealed = true;
            if (Scrollable.maybeOf(element) != null) {
              unawaited(Scrollable.ensureVisible(element, alignment: 0.5));
            }
          case HiddenPoint() || MissingPoint():
            break;
        }
      }
      if (--remaining < 0) {
        return null;
      }
      await Future<void>.delayed(_pollInterval);
    }
    return null;
  }

  void _trackSourceFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context != null && host.deviceOf(context) == 0) {
      _sourceFocus = FocusManager.instance.primaryFocus;
    }
  }

  void _restoreFocus(int id) {
    final device = host.indexOfId(id);
    final sourceFocus = _sourceFocus;
    final current = FocusManager.instance.primaryFocus;
    final currentContext = current?.context;
    if (current == null ||
        identical(current, sourceFocus) ||
        currentContext == null ||
        device == null ||
        host.deviceOf(currentContext) != device) {
      return;
    }
    final sourceContext = sourceFocus?.context;
    if (sourceFocus != null &&
        sourceContext != null &&
        sourceContext.mounted &&
        host.deviceOf(sourceContext) == 0) {
      sourceFocus.requestFocus();
    } else {
      current.unfocus();
    }
  }

  /// Stops mirroring. Gestures in flight are abandoned.
  void dispose() {
    _disposed = true;
    FocusManager.instance.removeListener(_trackSourceFocus);
    for (final gesture in _active.values) {
      gesture.end();
    }
    _active.clear();
  }
}

class _Gesture {
  _Gesture(this.capture, this.first, {required bool isScroll})
    : moved = isScroll {
    events.add(first);
  }

  final CapturedPoint capture;
  final PointerEvent first;
  final List<PointerEvent> events = [];

  /// Whether the pointer moved beyond the touch slop (or the gesture is a
  /// scroll), so it is a drag rather than a tap.
  bool moved;
  bool ended = false;
  Completer<void> _changed = Completer<void>();

  Future<void> get changed => _changed.future;

  void add(PointerEvent event) {
    if (ended) {
      return;
    }
    events.add(event);
    if (!moved && (event.position - first.position).distance > kTouchSlop) {
      moved = true;
    }
    _notify();
  }

  void end() {
    if (ended) {
      return;
    }
    ended = true;
    _notify();
  }

  void _notify() {
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
  }
}

/// Runs the gestures for one device one after another.
class _TargetQueue {
  final List<Future<void> Function()> _pending = [];
  bool _running = false;

  void add(Future<void> Function() run) {
    _pending.add(run);
    if (!_running) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    _running = true;
    while (_pending.isNotEmpty) {
      final run = _pending.removeAt(0);
      try {
        await run();
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'multi_device_preview',
            context: ErrorDescription('while mirroring a gesture'),
          ),
        );
      }
    }
    _running = false;
  }
}

/// Builds a fresh copy of [event] for another device.
///
/// `copyWith` is avoided on purpose: the pan/zoom events drop the pointer id
/// (so `GestureBinding` would treat the copies for several devices as one
/// pointer and discard all but the first), and scroll events would carry over
/// the source's `respond` callback.
///
/// Mouse pointers are sent as touches, so no hover state is created for the
/// synthetic device.
@internal
PointerEvent? synthesizePointerEvent(
  PointerEvent event, {
  required int pointer,
  required int device,
  required Offset position,
}) {
  // MouseTracker keeps hover state for mice and styluses; a synthetic device
  // would never be removed from it.
  final kind = switch (event.kind) {
    PointerDeviceKind.mouse ||
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus => PointerDeviceKind.touch,
    final kind => kind,
  };
  return switch (event) {
    PointerDownEvent() => PointerDownEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      pointer: pointer,
      kind: kind,
      device: device,
      position: position,
    ),
    PointerMoveEvent() => PointerMoveEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      pointer: pointer,
      kind: kind,
      device: device,
      position: position,
      delta: event.delta,
    ),
    PointerUpEvent() => PointerUpEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      pointer: pointer,
      kind: kind,
      device: device,
      position: position,
    ),
    PointerCancelEvent() => PointerCancelEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      pointer: pointer,
      kind: kind,
      device: device,
      position: position,
    ),
    PointerScrollEvent() => PointerScrollEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      kind: event.kind,
      device: device,
      position: position,
      scrollDelta: event.scrollDelta,
    ),
    PointerPanZoomStartEvent() => PointerPanZoomStartEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      device: device,
      pointer: pointer,
      position: position,
    ),
    PointerPanZoomUpdateEvent() => PointerPanZoomUpdateEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      device: device,
      pointer: pointer,
      position: position,
      pan: event.pan,
      panDelta: event.panDelta,
      scale: event.scale,
      rotation: event.rotation,
    ),
    PointerPanZoomEndEvent() => PointerPanZoomEndEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      device: device,
      pointer: pointer,
      position: position,
    ),
    _ => null,
  };
}
