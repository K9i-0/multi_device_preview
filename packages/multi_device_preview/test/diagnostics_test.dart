import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview/src/diagnostics.dart';

import 'support.dart';

final GlobalKey<NavigatorState> _sharedKey = GlobalKey(debugLabel: 'root');

void main() {
  test('explains a shared GlobalKey once and passes the error on', () {
    final hints = <String>[];
    final forwarded = <FlutterErrorDetails>[];
    final handler = withSharedGlobalKeyHint(
      forwarded.add,
      printHint: hints.add,
    );
    final details = FlutterErrorDetails(
      exception: FlutterError(
        'Multiple widgets used the same GlobalKey.\n'
        'The key [LabeledGlobalKey<NavigatorState>#1a2b3 root] was used by '
        '2 widgets:',
      ),
    );

    handler(details);
    handler(details);

    expect(forwarded, [details, details]);
    expect(hints, hasLength(1));
    expect(
      hints.single,
      contains(
        'The GlobalKey [LabeledGlobalKey<NavigatorState>#1a2b3 root] is used '
        'by more than one device.',
      ),
    );
    expect(hints.single, contains(requirementsUrl));
  });

  test('leaves other errors alone', () {
    final hints = <String>[];
    final forwarded = <FlutterErrorDetails>[];
    final handler = withSharedGlobalKeyHint(
      forwarded.add,
      printHint: hints.add,
    );
    final details = FlutterErrorDetails(exception: FlutterError('Overflow.'));

    handler(details);

    expect(forwarded, [details]);
    expect(hints, isEmpty);
  });

  testWidgets('recognizes the error Flutter reports for a key shared by '
      'devices', (tester) async {
    final hints = <String>[];
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = withSharedGlobalKeyHint(
      errors.add,
      printHint: hints.add,
    );
    final controller = MultiDevicePreviewController(devices: tallAndShort);
    addTearDown(controller.dispose);
    try {
      await pumpPreview(
        tester,
        controller: controller,
        appBuilder: (context, slot) => MaterialApp(
          navigatorKey: _sharedKey,
          home: const SizedBox(),
        ),
      );
    } finally {
      FlutterError.onError = original;
    }

    expect(errors, isNotEmpty);
    expect(hints, hasLength(1));
    expect(hints.single, contains('root]'));
  });
}
