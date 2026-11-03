import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'presets.dart';
import 'preview_device.dart';

/// The height of the toolbar.
@internal
const double kToolbarExtent = 48;

/// The height of the band holding the device labels.
@internal
const double kLabelExtent = 32;

/// The text scales offered in the settings sheet.
@internal
const List<double> kTextScaleChoices = [0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

/// Keys of the tool's own controls, for tests and automation.
@internal
abstract final class ChromeKeys {
  /// The input sync switch.
  static const sync = ValueKey<String>('multi_device_preview.sync');

  /// The restart button.
  static const restart = ValueKey<String>('multi_device_preview.restart');

  /// The add device button.
  static const add = ValueKey<String>('multi_device_preview.add');

  /// The settings sheet.
  static const sheet = ValueKey<String>('multi_device_preview.sheet');

  /// The remove button in the settings sheet.
  static const remove = ValueKey<String>('multi_device_preview.remove');

  /// The label above the device at [index].
  static ValueKey<String> label(int index) =>
      ValueKey<String>('multi_device_preview.label.$index');

  /// The text scale choice [scale] in the settings sheet.
  static ValueKey<String> textScale(double scale) =>
      ValueKey<String>('multi_device_preview.text_scale.$scale');

  /// The preset choice [id] in the settings sheet.
  static ValueKey<String> preset(String id) =>
      ValueKey<String>('multi_device_preview.preset.$id');
}

/// Which settings sheet is open.
@internal
sealed class ChromeSheet {
  const ChromeSheet();
}

/// Editing the device at [index].
@internal
final class EditDeviceSheet extends ChromeSheet {
  /// Creates a sheet for the device at [index].
  const EditDeviceSheet(this.index);

  /// The device being edited.
  final int index;
}

/// Choosing a device to add.
@internal
final class AddDeviceSheet extends ChromeSheet {
  /// Creates the add device sheet.
  const AddDeviceSheet();
}

/// The tool's controls, drawn in a layer over the devices.
///
/// The layer is not an ancestor of the devices, so its `Overlay` (used by
/// tooltips) is never found by the apps. Where it draws nothing, pointers pass
/// through to the devices below.
@internal
class PreviewChrome extends StatelessWidget {
  /// Creates the controls.
  const PreviewChrome({
    super.key,
    required this.controller,
    required this.deviceRects,
    required this.sheet,
    required this.onOpenSheet,
    required this.onCloseSheet,
  });

  /// The preview's controller.
  final MultiDevicePreviewController controller;

  /// Where each device (with its frame) is drawn, in this layer's
  /// coordinates.
  final List<Rect> deviceRects;

  /// The open sheet, if any.
  final ChromeSheet? sheet;

  /// Opens a sheet.
  final ValueChanged<ChromeSheet> onOpenSheet;

  /// Closes the sheet.
  final VoidCallback onCloseSheet;

  @override
  Widget build(BuildContext context) {
    final devices = controller.devices;
    final outOfSync = controller.outOfSyncDevices;
    final sheet = this.sheet;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: kToolbarExtent,
          child: _Toolbar(
            controller: controller,
            onAdd: () => onOpenSheet(const AddDeviceSheet()),
          ),
        ),
        for (var i = 0; i < devices.length && i < deviceRects.length; i++) ...[
          Positioned(
            left: deviceRects[i].left,
            top: kToolbarExtent,
            width: deviceRects[i].width,
            height: kLabelExtent,
            child: _DeviceLabel(
              key: ChromeKeys.label(i),
              device: devices[i],
              isSource: i == 0 && controller.syncEnabled && devices.length > 1,
              isOutOfSync: outOfSync.contains(i),
              onTap: () => onOpenSheet(EditDeviceSheet(i)),
            ),
          ),
          if (outOfSync.contains(i))
            Positioned.fromRect(
              rect: deviceRects[i].inflate(4),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
        if (sheet != null)
          Positioned.fill(
            child: _SheetScaffold(
              onDismiss: onCloseSheet,
              child: switch (sheet) {
                EditDeviceSheet(:final index) when index < devices.length =>
                  _DeviceSheet(
                    title: 'Device ${index + 1}',
                    device: devices[index],
                    onChanged: (device) => controller.setDevice(index, device),
                    onRemove: devices.length > 1
                        ? () {
                            onCloseSheet();
                            controller.removeDevice(index);
                          }
                        : null,
                    onClose: onCloseSheet,
                  ),
                EditDeviceSheet() => const SizedBox.shrink(),
                AddDeviceSheet() => _DeviceSheet(
                  title: 'Add device',
                  device: null,
                  onChanged: (device) {
                    onCloseSheet();
                    controller.addDevice(device);
                  },
                  onClose: onCloseSheet,
                ),
              },
            ),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.onAdd});

  final MultiDevicePreviewController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outOfSync = controller.outOfSyncDevices.length;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text('multi_device_preview', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (outOfSync > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$outOfSync out of sync — restart to realign',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Tooltip(
              message: 'Mirror input on the first device to the others',
              child: Row(
                children: [
                  const Icon(Icons.sync, size: 18),
                  const SizedBox(width: 4),
                  Text('Sync input', style: theme.textTheme.labelLarge),
                  Switch(
                    key: ChromeKeys.sync,
                    value: controller.syncEnabled,
                    onChanged: (value) => controller.syncEnabled = value,
                  ),
                ],
              ),
            ),
            IconButton(
              key: ChromeKeys.restart,
              tooltip: 'Restart all devices',
              icon: const Icon(Icons.restart_alt),
              onPressed: controller.restart,
            ),
            IconButton(
              key: ChromeKeys.add,
              tooltip: 'Add device',
              icon: const Icon(Icons.add_to_queue),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceLabel extends StatelessWidget {
  const _DeviceLabel({
    super.key,
    required this.device,
    required this.isSource,
    required this.isOutOfSync,
    required this.onTap,
  });

  final PreviewDevice device;
  final bool isSource;
  final bool isOutOfSync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSource)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.touch_app,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                if (isOutOfSync)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.sync_problem,
                      size: 14,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Flexible(
                  child: Text(
                    '${device.preset.name} · '
                    '${(device.textScale * 100).round()}%',
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.expand_more, size: 14, color: style?.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A modal bottom sheet built without a `Navigator`, which the tool does not
/// have.
class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Colors.black54),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: constraints.maxHeight * 0.8,
              ),
              child: Material(
                key: ChromeKeys.sheet,
                color: theme.colorScheme.surfaceContainerLow,
                elevation: 8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceSheet extends StatefulWidget {
  const _DeviceSheet({
    required this.title,
    required this.device,
    required this.onChanged,
    required this.onClose,
    this.onRemove,
  });

  final String title;
  final PreviewDevice? device;
  final ValueChanged<PreviewDevice> onChanged;
  final VoidCallback onClose;
  final VoidCallback? onRemove;

  @override
  State<_DeviceSheet> createState() => _DeviceSheetState();
}

class _DeviceSheetState extends State<_DeviceSheet> {
  late double _textScale = widget.device?.textScale ?? 1.0;

  void _select(DevicePreset preset) {
    widget.onChanged(PreviewDevice(preset: preset, textScale: _textScale));
  }

  void _selectTextScale(double scale) {
    setState(() => _textScale = scale);
    final device = widget.device;
    if (device != null) {
      widget.onChanged(PreviewDevice(preset: device.preset, textScale: scale));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Phones first: they are what most apps are checked on.
    final groups = <DeviceKind, List<DevicePreset>>{
      for (final kind in const [
        DeviceKind.phone,
        DeviceKind.foldable,
        DeviceKind.tablet,
        DeviceKind.desktop,
      ])
        kind: [],
    };
    for (final preset in allPresets) {
      groups.putIfAbsent(preset.kind, () => []).add(preset);
    }
    final selected = widget.device?.preset.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              if (widget.onRemove != null)
                TextButton.icon(
                  key: ChromeKeys.remove,
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text('Text size', style: theme.textTheme.labelLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final scale in kTextScaleChoices)
                ChoiceChip(
                  key: ChromeKeys.textScale(scale),
                  label: Text('${(scale * 100).round()}%'),
                  selected: _textScale == scale,
                  onSelected: (_) => _selectTextScale(scale),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final MapEntry(key: kind, value: presets) in groups.entries)
                if (presets.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      _kindLabel(kind),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final preset in presets)
                    ListTile(
                      key: ChromeKeys.preset(preset.id),
                      dense: true,
                      selected: preset.id == selected,
                      leading: Icon(
                        preset.id == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(preset.name),
                      subtitle: Text(
                        '${preset.portraitSize.width.round()} × '
                        '${preset.portraitSize.height.round()}'
                        '${preset.brand == null ? '' : ' · ${preset.brand}'}',
                      ),
                      onTap: () => _select(preset),
                    ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  static String _kindLabel(DeviceKind kind) => switch (kind) {
    DeviceKind.phone => 'Phones',
    DeviceKind.tablet => 'Tablets',
    DeviceKind.foldable => 'Foldables',
    DeviceKind.desktop => 'Desktop windows',
  };
}
