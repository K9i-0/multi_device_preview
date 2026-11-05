import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'anchor.dart';

/// What the sync modules need to know about the devices on screen.
@internal
abstract interface class SyncHost {
  /// The number of devices. Device 0 is the input source.
  int get deviceCount;

  /// Whether input is mirrored.
  bool get syncEnabled;

  /// A stable identifier of the device at [index], which survives devices
  /// being added, removed or moved.
  int idOf(int index);

  /// The current index of the device identified by [id], or null when it was
  /// removed.
  int? indexOfId(int id);

  /// The element at the root of the app on [device], or null while it is not
  /// mounted.
  Element? appElementOf(int device);

  /// The anchors of [device], or null while it is not laid out.
  AnchorIndex? anchorsOf(int device);

  /// The index of the device [context] belongs to, or null.
  int? deviceOf(BuildContext context);

  /// Records that [device] missed a mirrored gesture.
  void markOutOfSync(int device);

  /// Gives the keyboard focus back to the source device, to the node it
  /// focused last.
  void focusSource();
}
