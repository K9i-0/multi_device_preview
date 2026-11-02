import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

import 'support.dart';

void main() {
  late MultiDevicePreviewController controller;

  setUp(() => controller = MultiDevicePreviewController(devices: tallAndShort));
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => pumpPreview(
    tester,
    controller: controller,
    appBuilder: (context, slot) => const ProbeApp(),
  );

  EditableTextState field(WidgetTester tester, int device, String key) =>
      tester.state<EditableTextState>(
        inDevice(
          device,
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(EditableText),
          ),
        ),
      );

  testWidgets('text typed on the source appears on the others', (tester) async {
    await pump(tester);

    await tester.enterText(
      inDevice(0, find.byKey(const ValueKey('search'))),
      'flutter',
    );
    await settle(tester);

    expect(field(tester, 1, 'search').textEditingValue.text, 'flutter');
    // onChanged fires as if the user typed.
    expect(probeOf(tester, 1).changed, 'flutter');
  });

  testWidgets('text set without focus (Marionette enter_text) is synced', (
    tester,
  ) async {
    await pump(tester);

    field(tester, 0, 'search').userUpdateTextEditingValue(
      const TextEditingValue(text: 'agent'),
      SelectionChangedCause.keyboard,
    );
    await settle(tester);

    expect(field(tester, 1, 'search').textEditingValue.text, 'agent');
  });

  testWidgets('the source wins over edits on other devices', (tester) async {
    await pump(tester);
    field(
      tester,
      0,
      'search',
    ).userUpdateTextEditingValue(const TextEditingValue(text: 'source'), null);
    field(
      tester,
      1,
      'search',
    ).userUpdateTextEditingValue(const TextEditingValue(text: 'other'), null);
    await settle(tester);

    expect(field(tester, 1, 'search').textEditingValue.text, 'source');
  });

  testWidgets('fields are not synced while sync is off', (tester) async {
    controller.syncEnabled = false;
    await pump(tester);

    await tester.enterText(
      inDevice(0, find.byKey(const ValueKey('search'))),
      'flutter',
    );
    await settle(tester);

    expect(field(tester, 1, 'search').textEditingValue.text, isEmpty);
  });

  testWidgets('Enter on a search field submits on every device', (
    tester,
  ) async {
    await pump(tester);

    await tester.showKeyboard(
      inDevice(0, find.byKey(const ValueKey('search'))),
    );
    await settle(tester);
    tester.testTextInput.enterText('query');
    await pressEnter(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    expect(probeOf(tester, 0).submitted, 'query');
    expect(probeOf(tester, 1).submitted, 'query');
  });

  testWidgets('Enter on a "next" field is not sent', (tester) async {
    await pump(tester);

    await tester.showKeyboard(inDevice(0, find.byKey(const ValueKey('next'))));
    await settle(tester);
    tester.testTextInput.enterText('value');
    await pressEnter(tester);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await settle(tester);

    expect(probeOf(tester, 0).submitted, 'next value');
    expect(probeOf(tester, 1).submitted, isEmpty);
  });
}
