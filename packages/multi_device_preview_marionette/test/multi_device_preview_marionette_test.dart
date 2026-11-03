import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_marionette/multi_device_preview_marionette.dart';

void main() {
  late MultiDevicePreviewController controller;

  setUp(() => controller = MultiDevicePreviewController());
  tearDown(() => controller.dispose());

  PreviewCommand command(String name) =>
      previewCommands(controller).firstWhere((c) => c.name == name);

  test('schemas list every parameter with its type', () {
    final schema = inputSchemaOf(command('setDevice')).toJson();
    final properties = schema['properties']! as Map<String, Object?>;
    expect(properties.keys, ['index', 'preset', 'textScale', 'orientation']);
    expect((properties['orientation']! as Map)['type'], 'string');
    expect((properties['index']! as Map)['type'], 'integer');
    expect((properties['textScale']! as Map)['type'], 'number');
    expect(schema['required'], ['index']);
  });

  test('results map to Marionette results', () async {
    expect(
      await runAsMarionetteExtension(command('setSync'), {'enabled': 'false'}),
      isA<MarionetteExtensionSuccess>(),
    );
    expect(controller.syncEnabled, isFalse);

    expect(
      await runAsMarionetteExtension(command('setSync'), {}),
      isA<MarionetteExtensionInvalidParams>(),
    );
    // No preview attached: a runtime error, not invalid params.
    expect(
      await runAsMarionetteExtension(command('saveScreenshot'), {
        'path': '/tmp/never-written.png',
      }),
      isA<MarionetteExtensionError>(),
    );
  });

  test('registers one extension per command', () {
    registerMultiDevicePreviewMarionetteExtensions(controller);
    final names = customExtensionRegistry.map((e) => e.name);
    for (final c in previewCommands(controller)) {
      expect(names, contains('multiDevicePreview.${c.name}'));
    }
  });
}
