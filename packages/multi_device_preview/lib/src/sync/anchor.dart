import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A landmark used to find "the same element" on every device.
///
/// Two elements on different devices correspond when they have equal anchors
/// and the same position (ordinal) among elements with that anchor in tree
/// order.
@immutable
class Anchor {
  /// Creates an anchor of [kind] with [value].
  const Anchor(this.kind, this.value);

  /// The category of the anchor, for example `key` or `text`.
  final String kind;

  /// The value compared across devices, for example the text itself.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is Anchor && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'Anchor($kind: $value)';
}

/// Returns the anchor of [element], or null when it has none.
///
/// Add resolvers to `MultiDevicePreview.anchorResolvers` to recognize widgets
/// the built-in ones do not know, such as images from third-party packages.
/// Custom resolvers run before the built-in ones.
typedef AnchorResolver = Anchor? Function(Element element);

/// The prefix of keys used by multi_device_preview itself. They differ per
/// device, so they are never used as anchors.
const String toolKeyPrefix = 'multi_device_preview.';

/// The anchors recognized out of the box, in priority order.
const List<AnchorResolver> builtInAnchorResolvers = [
  keyAnchor,
  semanticsAnchor,
  imageAnchor,
  textAnchor,
  editableTextAnchor,
];

/// A `ValueKey<String>` on the widget.
Anchor? keyAnchor(Element element) {
  final key = element.widget.key;
  if (key is ValueKey<String> && !key.value.startsWith(toolKeyPrefix)) {
    return Anchor('key', key.value);
  }
  return null;
}

/// The `identifier` of a [Semantics] widget, or else its `label`, or else its
/// `tooltip` (which `IconButton.tooltip` sets). Matches image banners and icon
/// buttons without text.
Anchor? semanticsAnchor(Element element) {
  final widget = element.widget;
  if (widget is! Semantics) {
    return null;
  }
  final identifier = widget.properties.identifier;
  if (identifier != null && identifier.isNotEmpty) {
    return Anchor('semantics-id', identifier);
  }
  final label = widget.properties.label;
  if (label != null && label.isNotEmpty) {
    return Anchor('semantics-label', label);
  }
  final tooltip = widget.properties.tooltip;
  if (tooltip != null && tooltip.isNotEmpty) {
    return Anchor('semantics-tooltip', tooltip);
  }
  return null;
}

/// The URL or asset name of an [Image].
Anchor? imageAnchor(Element element) {
  final widget = element.widget;
  if (widget is! Image) {
    return null;
  }
  final source = imageProviderSource(widget.image);
  return source == null ? null : Anchor('image', source);
}

/// Describes where [provider] loads from: a URL, an asset or a file path.
///
/// Returns null for providers it does not know. Useful for writing an
/// [AnchorResolver] for third-party image widgets.
String? imageProviderSource(ImageProvider provider) {
  return switch (provider) {
    NetworkImage(:final url) => url,
    AssetImage(:final assetName, :final package) =>
      package == null ? assetName : 'packages/$package/$assetName',
    ExactAssetImage(:final assetName, :final package) =>
      package == null ? assetName : 'packages/$package/$assetName',
    ResizeImage(:final imageProvider) => imageProviderSource(imageProvider),
    _ => null,
  };
}

/// The plain text of a [RichText]. `Text` builds a `RichText`, so this covers
/// both.
Anchor? textAnchor(Element element) {
  final widget = element.widget;
  if (widget is! RichText) {
    return null;
  }
  final text = widget.text.toPlainText(includeSemanticsLabels: false).trim();
  return text.isEmpty ? null : Anchor('text', text);
}

/// Any [EditableText]. Input fields correspond by their order.
Anchor? editableTextAnchor(Element element) {
  return element.widget is EditableText ? const Anchor('editable', '') : null;
}

/// An anchor found in a device, with what it is attached to.
@internal
class AnchorHit {
  AnchorHit._(this.anchor, this.ordinal, this.element, this.renderObject);

  /// The anchor.
  final Anchor anchor;

  /// The position among elements with the same [anchor], in tree order.
  final int ordinal;

  /// The element the anchor was found on.
  final Element element;

  /// The render object painting the element.
  final RenderBox renderObject;
}

/// Every anchor under a device's app root, in tree order.
@internal
class AnchorIndex {
  AnchorIndex._(this.root, this.hits, this.counts);

  /// Collects the anchors under [rootElement], whose render object is
  /// [root].
  factory AnchorIndex.collect(
    Element rootElement,
    RenderBox root, {
    List<AnchorResolver> resolvers = builtInAnchorResolvers,
  }) {
    final hits = <AnchorHit>[];
    final counts = <Anchor, int>{};
    void visit(Element element) {
      for (final resolver in resolvers) {
        final anchor = resolver(element);
        if (anchor == null) {
          continue;
        }
        final renderObject = element.findRenderObject();
        if (renderObject is RenderBox && renderObject.attached) {
          final ordinal = counts[anchor] ?? 0;
          counts[anchor] = ordinal + 1;
          hits.add(AnchorHit._(anchor, ordinal, element, renderObject));
        }
        break;
      }
      element.visitChildElements(visit);
    }

    rootElement.visitChildElements(visit);
    return AnchorIndex._(root, hits, counts);
  }

  /// The app root of the device.
  final RenderBox root;

  /// The anchors in tree order.
  final List<AnchorHit> hits;

  /// How many elements carry each anchor.
  final Map<Anchor, int> counts;

  final Map<AnchorHit, bool> _visible = {};

  /// Finds the element with [anchor] at [ordinal].
  AnchorHit? find(Anchor anchor, int ordinal) {
    for (final hit in hits) {
      if (hit.anchor == anchor && hit.ordinal == ordinal) {
        return hit;
      }
    }
    return null;
  }

  /// Whether [hit] can be seen and touched: a hit test at its center reaches
  /// it.
  ///
  /// Excludes pages covered by another route, hidden tabs of an
  /// `IndexedStack`, and elements scrolled out of view or outside the device.
  bool isVisible(AnchorHit hit) {
    return _visible.putIfAbsent(hit, () {
      final box = hit.renderObject;
      if (!box.attached || !box.hasSize || box.size.isEmpty) {
        return false;
      }
      final center = box.localToGlobal(box.size.center(Offset.zero));
      return hitTestPath(root, center).any((e) => identical(e.target, box));
    });
  }
}

/// The hit test path at [globalPosition] inside [root], deepest first.
///
/// The tool's own gate sits above [root], so this always reaches the app.
@internal
Iterable<HitTestEntry> hitTestPath(RenderBox root, Offset globalPosition) {
  final local = root.globalToLocal(globalPosition);
  final result = BoxHitTestResult();
  if (!root.size.contains(local)) {
    return const [];
  }
  root.hitTest(result, position: local);
  return result.path;
}

/// Whether [node] is [ancestor] or below it.
@internal
bool isSelfOrDescendant(RenderObject node, RenderObject ancestor) {
  RenderObject? current = node;
  while (current != null) {
    if (identical(current, ancestor)) {
      return true;
    }
    current = current.parent;
  }
  return false;
}
