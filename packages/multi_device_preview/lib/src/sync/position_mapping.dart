import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'anchor.dart';

/// A receiver (or base box) covering more than this share of the screen is
/// too coarse to locate a tap precisely.
const double _largeAreaRatio = 0.5;

/// Where a pointer went down on the source device, described so that the same
/// spot can be found on another device.
@internal
@immutable
class CapturedPoint {
  const CapturedPoint._({
    required this.anchor,
    required this.ordinal,
    required this.depth,
    required this.relative,
    required this.precise,
  });

  /// The anchor inside the base box, or null when the point is described
  /// relative to the whole screen.
  final Anchor? anchor;

  /// The ordinal of [anchor].
  final int ordinal;

  /// How many parents to walk up from the anchor to reach the base box.
  final int depth;

  /// The position inside the base box, from (0, 0) to (1, 1).
  final Offset relative;

  /// Whether the point identifies a specific element. A tap that is not
  /// precise is not mirrored, because it could hit a different element on a
  /// device of another height.
  final bool precise;

  @override
  String toString() =>
      'CapturedPoint($anchor #$ordinal, depth: $depth, '
      'relative: $relative, precise: $precise)';
}

/// Describes [globalPosition] on the device whose anchors are [index].
///
/// 1. The deepest gesture receiver (a `Listener`, which `GestureDetector`,
///    `InkWell` and scroll views build) on the hit path is the pressed button,
///    unless it covers most of the screen.
/// 2. The button is the base box when it contains an anchor. Otherwise the
///    deepest box on the hit path containing a visible anchor is.
/// 3. The anchor inside the base box shared by the fewest elements is chosen.
/// 4. The position is stored relative to the base box.
@internal
CapturedPoint capturePoint(AnchorIndex index, Offset globalPosition) {
  final root = index.root;
  final screenArea = _area(root.size);
  final path = hitTestPath(root, globalPosition).toList();

  RenderBox? button;
  for (final entry in path) {
    final target = entry.target;
    if (target is RenderPointerListener && !identical(target, root)) {
      button = _area(target.size) <= screenArea * _largeAreaRatio
          ? target
          : null;
      break;
    }
  }

  // The cheap parent walk runs first; only anchors inside the box pay for a
  // visibility hit test.
  List<AnchorHit> hitsInside(RenderObject box) => [
    for (final hit in index.hits)
      if (isSelfOrDescendant(hit.renderObject, box) && index.isVisible(hit))
        hit,
  ];

  RenderBox? base;
  var candidates = const <AnchorHit>[];
  if (button != null) {
    final inside = hitsInside(button);
    if (inside.isNotEmpty) {
      base = button;
      candidates = inside;
    }
  }
  if (base == null) {
    for (final entry in path) {
      final target = entry.target;
      if (target is! RenderBox || identical(target, root)) {
        continue;
      }
      final inside = hitsInside(target);
      if (inside.isNotEmpty) {
        base = target;
        candidates = inside;
        break;
      }
    }
  }

  if (base == null || candidates.isEmpty) {
    return CapturedPoint._(
      anchor: null,
      ordinal: 0,
      depth: 0,
      relative: _relative(root, globalPosition),
      precise: false,
    );
  }

  var chosen = candidates.first;
  for (final hit in candidates.skip(1)) {
    if (index.counts[hit.anchor]! < index.counts[chosen.anchor]!) {
      chosen = hit;
    }
  }
  var depth = 0;
  RenderObject? current = chosen.renderObject;
  while (current != null && !identical(current, base)) {
    current = current.parent;
    depth++;
  }
  return CapturedPoint._(
    anchor: chosen.anchor,
    ordinal: chosen.ordinal,
    depth: depth,
    relative: _relative(base, globalPosition),
    precise: _area(base.size) <= screenArea * _largeAreaRatio,
  );
}

/// The outcome of looking up a [CapturedPoint] on another device.
@internal
sealed class ResolvedPoint {
  const ResolvedPoint();
}

/// The point was found at [globalPosition].
@internal
final class FoundPoint extends ResolvedPoint {
  const FoundPoint(this.globalPosition);

  /// The position to send the event to, in global coordinates.
  final Offset globalPosition;
}

/// The anchor exists but is not visible; scrolling [element] into view may
/// reveal it.
@internal
final class HiddenPoint extends ResolvedPoint {
  const HiddenPoint(this.element);

  /// The element carrying the anchor.
  final Element element;
}

/// The anchor does not exist (yet) on the device.
@internal
final class MissingPoint extends ResolvedPoint {
  const MissingPoint();
}

/// Finds [point] on the device whose anchors are [index].
@internal
ResolvedPoint resolvePoint(AnchorIndex index, CapturedPoint point) {
  final anchor = point.anchor;
  if (anchor == null) {
    return FoundPoint(_absolute(index.root, point.relative));
  }
  final hit = index.find(anchor, point.ordinal);
  if (hit == null) {
    return const MissingPoint();
  }
  if (!index.isVisible(hit)) {
    return HiddenPoint(hit.element);
  }
  RenderObject box = hit.renderObject;
  for (var i = 0; i < point.depth; i++) {
    final parent = box.parent;
    if (parent == null || identical(parent, index.root.parent)) {
      break;
    }
    box = parent;
  }
  if (box is! RenderBox || !box.hasSize) {
    box = hit.renderObject;
  }
  return FoundPoint(_absolute(box, point.relative));
}

double _area(Size size) => size.width * size.height;

Offset _relative(RenderBox box, Offset globalPosition) {
  final local = box.globalToLocal(globalPosition);
  final size = box.size;
  return Offset(
    size.width == 0 ? 0 : local.dx / size.width,
    size.height == 0 ? 0 : local.dy / size.height,
  );
}

Offset _absolute(RenderBox box, Offset relative) {
  return box.localToGlobal(
    Offset(relative.dx * box.size.width, relative.dy * box.size.height),
  );
}
