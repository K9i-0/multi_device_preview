import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'controller.dart';
import 'preview_device.dart';
import 'sync/input_gate.dart';

/// The type of a [PreviewCommandParam].
enum PreviewParamType {
  /// A string.
  string,

  /// An integer.
  integer,

  /// A floating point number.
  number,

  /// `true` or `false`.
  boolean,
}

/// A parameter of a [PreviewCommand].
///
/// Values always arrive as strings (service extensions only carry strings)
/// and are parsed by the command.
@immutable
class PreviewCommandParam {
  /// Describes a parameter.
  const PreviewCommandParam(
    this.name,
    this.type,
    this.description, {
    this.required = false,
  });

  /// The parameter name.
  final String name;

  /// The type of the value.
  final PreviewParamType type;

  /// What the parameter means.
  final String description;

  /// Whether the parameter must be given.
  final bool required;
}

/// Thrown by a [PreviewCommand] when its arguments are invalid.
class PreviewCommandException implements Exception {
  /// Creates an exception with [message].
  const PreviewCommandException(this.message);

  /// What is wrong with the arguments.
  final String message;

  @override
  String toString() => 'PreviewCommandException: $message';
}

/// An action that tools and AI agents can run on a preview: inspect it,
/// switch devices, toggle sync, restart, save screenshots.
///
/// [previewCommands] lists them. They are exposed as VM service extensions
/// by [registerPreviewServiceExtensions], and as Marionette tools by the
/// `multi_device_preview_marionette` package.
@immutable
class PreviewCommand {
  /// Describes a command.
  const PreviewCommand({
    required this.name,
    required this.description,
    required this._run,
    this.params = const [],
  });

  /// The command name, in lowerCamelCase.
  final String name;

  /// What the command does, for humans and agents.
  final String description;

  /// The parameters the command accepts.
  final List<PreviewCommandParam> params;

  final Future<Map<String, Object?>> Function(Map<String, String> args) _run;

  /// Runs the command with [args]. Returns a JSON-encodable map, and throws a
  /// [PreviewCommandException] for missing or invalid arguments.
  Future<Map<String, Object?>> run(Map<String, String> args) async {
    for (final param in params) {
      final value = args[param.name];
      if (param.required && (value == null || value.isEmpty)) {
        throw PreviewCommandException('Missing parameter: ${param.name}');
      }
    }
    return _run(args);
  }
}

/// The device id used for trackpad gestures injected by the `panZoom`
/// command. It is below [kSyntheticDeviceBase], so the gesture is treated as
/// real input and mirrored to the other devices.
const int kInjectedTrackpadDevice = 90;

/// The commands available for [controller].
List<PreviewCommand> previewCommands(MultiDevicePreviewController controller) {
  return [
    PreviewCommand(
      name: 'getState',
      description:
          'Lists the devices (index, preset, text scale, logical size, '
          'screen key for ancestor_keys, out-of-sync mark) and whether '
          'input sync is on.',
      run: (_) async => _state(controller),
    ),
    PreviewCommand(
      name: 'listPresets',
      description: 'Lists the device presets that can be used.',
      run: (_) async => {
        'presets': [
          for (final preset in DevicePresets.all)
            {
              'id': preset.id,
              'name': preset.name,
              'kind': preset.kind.name,
              'platform': preset.platform.name,
              'width': preset.portraitSize.width,
              'height': preset.portraitSize.height,
            },
        ],
      },
    ),
    PreviewCommand(
      name: 'setSync',
      description:
          'Turns input sync on or off. While on, input on device 0 is '
          'mirrored to the other devices.',
      params: const [
        PreviewCommandParam(
          'enabled',
          PreviewParamType.boolean,
          'Whether to mirror input.',
          required: true,
        ),
      ],
      run: (args) async {
        controller.syncEnabled = _bool(args, 'enabled')!;
        return _state(controller);
      },
    ),
    PreviewCommand(
      name: 'restart',
      description:
          'Rebuilds the app on every device from scratch and clears the '
          'out-of-sync marks.',
      run: (_) async {
        controller.restart();
        return _state(controller);
      },
    ),
    PreviewCommand(
      name: 'setDevice',
      description:
          'Changes the preset and/or text scale of the device at index, '
          'keeping its app state.',
      params: const [
        PreviewCommandParam(
          'index',
          PreviewParamType.integer,
          'The device index, from 0.',
          required: true,
        ),
        PreviewCommandParam(
          'preset',
          PreviewParamType.string,
          'A preset id from listPresets.',
        ),
        PreviewCommandParam(
          'textScale',
          PreviewParamType.number,
          'The text scale factor, for example 1.5.',
        ),
      ],
      run: (args) async {
        final index = _index(controller, args, 'index')!;
        final current = controller.devices[index];
        controller.setDevice(
          index,
          PreviewDevice(
            preset: _preset(args) ?? current.preset,
            textScale: _textScale(args) ?? current.textScale,
          ),
        );
        return _state(controller);
      },
    ),
    PreviewCommand(
      name: 'addDevice',
      description: 'Adds a device at the right end.',
      params: const [
        PreviewCommandParam(
          'preset',
          PreviewParamType.string,
          'A preset id from listPresets.',
          required: true,
        ),
        PreviewCommandParam(
          'textScale',
          PreviewParamType.number,
          'The text scale factor. Defaults to 1.',
        ),
      ],
      run: (args) async {
        controller.addDevice(
          PreviewDevice(
            preset: _preset(args)!,
            textScale: _textScale(args) ?? 1.0,
          ),
        );
        return _state(controller);
      },
    ),
    PreviewCommand(
      name: 'removeDevice',
      description: 'Removes the device at index. The last one stays.',
      params: const [
        PreviewCommandParam(
          'index',
          PreviewParamType.integer,
          'The device index, from 0.',
          required: true,
        ),
      ],
      run: (args) async {
        final index = _index(controller, args, 'index')!;
        if (controller.devices.length == 1) {
          throw const PreviewCommandException(
            'The last device cannot be removed.',
          );
        }
        controller.removeDevice(index);
        return _state(controller);
      },
    ),
    PreviewCommand(
      name: 'saveScreenshot',
      description:
          'Saves a PNG of all devices (or one device, with its frame) to '
          'path. Smaller than the screenshots returned over MCP. Fails when '
          'the window is hidden behind other windows, where macOS stops '
          'rendering it.',
      params: const [
        PreviewCommandParam(
          'path',
          PreviewParamType.string,
          'The file to write, for example /tmp/preview.png.',
          required: true,
        ),
        PreviewCommandParam(
          'device',
          PreviewParamType.integer,
          'Only capture the device at this index.',
        ),
        PreviewCommandParam(
          'pixelRatio',
          PreviewParamType.number,
          'Output pixels per logical pixel. Defaults to 1.',
        ),
      ],
      run: (args) async {
        final path = _string(args, 'path')!;
        final device = _index(controller, args, 'device');
        final pixelRatio = _double(args, 'pixelRatio') ?? 1.0;
        if (pixelRatio <= 0) {
          throw const PreviewCommandException('pixelRatio must be positive.');
        }
        final png = await controller.captureScreenshot(
          device: device,
          pixelRatio: pixelRatio,
        );
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
        return {'path': file.absolute.path, 'bytes': png.length};
      },
    ),
    PreviewCommand(
      name: 'panZoom',
      description:
          'Scrolls with a two-finger trackpad gesture at (x, y) in window '
          'coordinates (the bounds x/y reported by Marionette), moving by '
          '(dx, dy). It travels the same path as a real trackpad, so it is '
          'mirrored like one.',
      params: const [
        PreviewCommandParam(
          'x',
          PreviewParamType.number,
          'Window x.',
          required: true,
        ),
        PreviewCommandParam(
          'y',
          PreviewParamType.number,
          'Window y.',
          required: true,
        ),
        PreviewCommandParam(
          'dx',
          PreviewParamType.number,
          'Horizontal pan. Defaults to 0.',
        ),
        PreviewCommandParam(
          'dy',
          PreviewParamType.number,
          'Vertical pan; negative scrolls content up. Defaults to 0.',
        ),
        PreviewCommandParam(
          'durationMs',
          PreviewParamType.integer,
          'How long the gesture takes. Defaults to 300.',
        ),
      ],
      run: (args) async {
        await injectPanZoom(
          Offset(_double(args, 'x')!, _double(args, 'y')!),
          Offset(_double(args, 'dx') ?? 0, _double(args, 'dy') ?? 0),
          duration: Duration(milliseconds: _int(args, 'durationMs') ?? 300),
        );
        return {'ok': true};
      },
    ),
  ];
}

/// Sends a trackpad pan from [position] moving by [pan] over [duration], as
/// if it came from a real trackpad.
Future<void> injectPanZoom(
  Offset position,
  Offset pan, {
  Duration duration = const Duration(milliseconds: 300),
  int steps = 10,
}) async {
  final pointer = _nextInjectedPointer++;
  final binding = GestureBinding.instance;
  binding.handlePointerEvent(
    PointerPanZoomStartEvent(
      device: kInjectedTrackpadDevice,
      pointer: pointer,
      position: position,
    ),
  );
  for (var i = 1; i <= steps; i++) {
    await Future<void>.delayed(duration ~/ steps);
    binding.handlePointerEvent(
      PointerPanZoomUpdateEvent(
        device: kInjectedTrackpadDevice,
        pointer: pointer,
        position: position,
        pan: pan * (i / steps),
        panDelta: pan / steps.toDouble(),
      ),
    );
  }
  binding.handlePointerEvent(
    PointerPanZoomEndEvent(
      device: kInjectedTrackpadDevice,
      pointer: pointer,
      position: position,
    ),
  );
}

int _nextInjectedPointer = 9000;

MultiDevicePreviewController? _extensionController;
final Set<String> _registeredExtensions = {};

/// Registers [previewCommands] as VM service extensions named
/// `ext.multi_device_preview.<command>`, so that tools connected to the VM
/// service can drive the preview.
///
/// Does nothing in release mode. Calling it again (for example from a second
/// preview) points the extensions at the new [controller].
void registerPreviewServiceExtensions(MultiDevicePreviewController controller) {
  if (kReleaseMode) {
    return;
  }
  _extensionController = controller;
  for (final command in previewCommands(controller)) {
    final method = 'ext.multi_device_preview.${command.name}';
    if (!_registeredExtensions.add(method)) {
      continue;
    }
    developer.registerExtension(method, (method, parameters) async {
      final current = _extensionController;
      if (current == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'No preview is running.',
        );
      }
      final target = previewCommands(current)
          .firstWhere((c) => c.name == command.name);
      try {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(await target.run(parameters)),
        );
      } on PreviewCommandException catch (error) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          error.message,
        );
      } catch (error) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$error',
        );
      }
    });
  }
}

Map<String, Object?> _state(MultiDevicePreviewController controller) {
  final outOfSync = controller.outOfSyncDevices;
  return {
    'syncEnabled': controller.syncEnabled,
    'generation': controller.generation,
    'devices': [
      for (final (index, device) in controller.devices.indexed)
        {
          'index': index,
          'preset': device.preset.id,
          'name': device.preset.name,
          'textScale': device.textScale,
          'width': device.screenSize.width,
          'height': device.screenSize.height,
          'screenKey': DeviceSlot.screenKeyOf(index).value,
          'outOfSync': outOfSync.contains(index),
          'isSource': index == 0,
        },
    ],
  };
}

String? _string(Map<String, String> args, String name) {
  final value = args[name];
  return value == null || value.isEmpty ? null : value;
}

int? _int(Map<String, String> args, String name) {
  final value = _string(args, name);
  if (value == null) {
    return null;
  }
  return int.tryParse(value) ??
      (throw PreviewCommandException('$name must be an integer: $value'));
}

double? _double(Map<String, String> args, String name) {
  final value = _string(args, name);
  if (value == null) {
    return null;
  }
  return double.tryParse(value) ??
      (throw PreviewCommandException('$name must be a number: $value'));
}

bool? _bool(Map<String, String> args, String name) {
  return switch (_string(args, name)) {
    null => null,
    'true' => true,
    'false' => false,
    final value => throw PreviewCommandException(
      '$name must be true or false: $value',
    ),
  };
}

int? _index(
  MultiDevicePreviewController controller,
  Map<String, String> args,
  String name,
) {
  final index = _int(args, name);
  if (index != null && (index < 0 || index >= controller.devices.length)) {
    throw PreviewCommandException(
      '$name is out of range: $index (devices: ${controller.devices.length})',
    );
  }
  return index;
}

DevicePreset? _preset(Map<String, String> args) {
  final id = _string(args, 'preset');
  if (id == null) {
    return null;
  }
  for (final preset in DevicePresets.all) {
    if (preset.id == id) {
      return preset;
    }
  }
  throw PreviewCommandException('Unknown preset: $id. See listPresets.');
}

double? _textScale(Map<String, String> args) {
  final scale = _double(args, 'textScale');
  if (scale != null && scale <= 0) {
    throw const PreviewCommandException('textScale must be positive.');
  }
  return scale;
}
