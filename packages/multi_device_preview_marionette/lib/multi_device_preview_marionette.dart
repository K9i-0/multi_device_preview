/// Exposes multi_device_preview commands as Marionette MCP tools.
library;

import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

/// The prefix of the Marionette extensions registered by
/// [registerMultiDevicePreviewMarionetteExtensions].
const String multiDevicePreviewExtensionPrefix = 'multiDevicePreview.';

/// The Marionette configuration recommended for a preview.
///
/// `CompactionMode.none` keeps every element in `get_interactive_elements`,
/// so an agent can compare sizes and text scales across devices.
const MarionetteConfiguration multiDevicePreviewMarionetteConfiguration =
    MarionetteConfiguration(compaction: CompactionMode.none);

/// Registers every command of `previewCommands` as a Marionette extension
/// named `multiDevicePreview.<command>`, with a typed input schema, so they
/// show up as MCP tools.
///
/// Initialize `MarionetteBinding` before calling it and before
/// `runMultiDevicePreview`:
///
/// ```dart
/// void main() {
///   MarionetteBinding.ensureInitialized(
///     multiDevicePreviewMarionetteConfiguration,
///   );
///   final controller = MultiDevicePreviewController();
///   registerMultiDevicePreviewMarionetteExtensions(controller);
///   runMultiDevicePreview(
///     controller: controller,
///     appBuilder: (context, slot) => const MyApp(),
///   );
/// }
/// ```
///
/// Each extension can only be registered once per isolate.
void registerMultiDevicePreviewMarionetteExtensions(
  MultiDevicePreviewController controller,
) {
  for (final command in previewCommands(controller)) {
    registerMarionetteExtension(
      name: '$multiDevicePreviewExtensionPrefix${command.name}',
      description: command.description,
      inputSchema: inputSchemaOf(command),
      callback: (params) => runAsMarionetteExtension(command, params),
    );
  }
}

/// The Marionette input schema describing the parameters of [command].
ExtensionInputSchema inputSchemaOf(PreviewCommand command) {
  return ExtensionInputSchema(
    properties: {
      for (final param in command.params)
        param.name: switch (param.type) {
          PreviewParamType.string => ExtensionParam.string(
            description: param.description,
          ),
          PreviewParamType.integer => ExtensionParam.integer(
            description: param.description,
          ),
          PreviewParamType.number => ExtensionParam.number(
            description: param.description,
          ),
          PreviewParamType.boolean => ExtensionParam.boolean(
            description: param.description,
          ),
        },
    },
    required: [
      for (final param in command.params)
        if (param.required) param.name,
    ],
  );
}

/// Runs [command] with [params] and converts the outcome to a Marionette
/// result.
Future<MarionetteExtensionResult> runAsMarionetteExtension(
  PreviewCommand command,
  Map<String, String> params,
) async {
  try {
    return MarionetteExtensionResult.success(await command.run(params));
  } on PreviewCommandException catch (error) {
    return MarionetteExtensionResult.invalidParams(error.message);
  } catch (error) {
    return MarionetteExtensionResult.error(0, '$error');
  }
}
