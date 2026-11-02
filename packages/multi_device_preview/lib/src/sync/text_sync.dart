import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sync_host.dart';

/// How often the input fields are compared.
const Duration kTextSyncInterval = Duration(milliseconds: 100);

/// How long to wait after Enter before submitting on the other devices, so
/// the source finishes its own submission first.
const Duration kSubmitDelay = Duration(milliseconds: 100);

/// The actions submitted on the other devices. Others (`next` in particular)
/// would move focus there and steal it from the source.
const Set<TextInputAction> mirroredTextInputActions = {
  TextInputAction.done,
  TextInputAction.go,
  TextInputAction.search,
  TextInputAction.send,
};

/// Keeps the input fields of every device equal to the source device's.
///
/// Fields correspond by their order in the tree. The fields are compared at a
/// fixed interval rather than by listening to focus or controllers, so text
/// typed on the keyboard and text set by Marionette's `enter_text` (which
/// does not move focus) are both picked up. Values are applied with
/// `EditableTextState.userUpdateTextEditingValue`, which fires `onChanged`
/// like typing does.
///
/// A device with a different number of fields (still loading, or on another
/// page) is left alone.
@internal
class TextSync {
  /// Creates a text sync for the devices of [host].
  TextSync(this.host) {
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  /// The devices.
  final SyncHost host;

  Timer? _timer;
  final Set<Timer> _submits = {};

  /// Starts or stops comparing fields.
  set running(bool value) {
    if (value == (_timer != null)) {
      return;
    }
    if (value) {
      _timer = Timer.periodic(kTextSyncInterval, (_) => syncNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Copies the source fields to the other devices once.
  void syncNow() {
    if (!host.syncEnabled || host.deviceCount < 2) {
      return;
    }
    final source = editableTextsOf(0);
    if (source.isEmpty) {
      return;
    }
    for (var device = 1; device < host.deviceCount; device++) {
      final targets = editableTextsOf(device);
      if (targets.length != source.length) {
        continue;
      }
      for (var i = 0; i < source.length; i++) {
        _apply(source[i].textEditingValue, targets[i]);
      }
    }
  }

  /// The input fields of [device], in tree order.
  List<EditableTextState> editableTextsOf(int device) {
    final root = host.appElementOf(device);
    if (root == null) {
      return const [];
    }
    final states = <EditableTextState>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is EditableTextState) {
        states.add(element.state as EditableTextState);
      }
      element.visitChildElements(visit);
    }

    root.visitChildElements(visit);
    return states;
  }

  void _apply(TextEditingValue value, EditableTextState target) {
    if (!target.mounted || target.textEditingValue.text == value.text) {
      return;
    }
    final length = value.text.length;
    final selection = value.selection.isValid
        ? TextSelection(
            baseOffset: value.selection.baseOffset.clamp(0, length),
            extentOffset: value.selection.extentOffset.clamp(0, length),
          )
        : TextSelection.collapsed(offset: length);
    target.userUpdateTextEditingValue(
      TextEditingValue(text: value.text, selection: selection),
      SelectionChangedCause.keyboard,
    );
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        !host.syncEnabled ||
        host.deviceCount < 2) {
      return false;
    }
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) {
      return false;
    }
    final source = editableTextsOf(0);
    final index = source.indexWhere(
      (s) => identical(s.widget.focusNode, focus),
    );
    if (index < 0) {
      return false;
    }
    final field = source[index].widget;
    final action =
        field.textInputAction ??
        (field.keyboardType == TextInputType.multiline
            ? TextInputAction.newline
            : TextInputAction.done);
    if (!mirroredTextInputActions.contains(action)) {
      return false;
    }
    final value = source[index].textEditingValue;
    final targets = <EditableTextState>[
      for (var device = 1; device < host.deviceCount; device++)
        if (editableTextsOf(device) case final fields
            when fields.length == source.length)
          fields[index],
    ];
    late final Timer timer;
    timer = Timer(kSubmitDelay, () {
      _submits.remove(timer);
      for (final target in targets) {
        if (!target.mounted) {
          continue;
        }
        _apply(value, target);
        target.performAction(action);
      }
    });
    _submits.add(timer);
    return false;
  }

  /// Stops syncing.
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    running = false;
    for (final timer in _submits) {
      timer.cancel();
    }
    _submits.clear();
  }
}
