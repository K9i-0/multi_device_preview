import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_example/app.dart';
import 'package:multi_device_preview_example/example_keys.dart';
import 'package:patrol/patrol.dart';

const _deviceCount = 3;
const _sync = ValueKey('multi_device_preview.sync');
const _restart = ValueKey('multi_device_preview.restart');

Finder _inDevice(int index, Key key) => find.descendant(
  of: find.byKey(DeviceSlot.screenKeyOf(index)),
  matching: find.byKey(key),
);

Future<void> _startPreview(PatrolIntegrationTester $) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await $.pumpWidgetAndSettle(
    MultiDevicePreview(
      devices: const [
        PreviewDevice(preset: DevicePresets.iPhone17),
        PreviewDevice(preset: DevicePresets.iPhoneSe3),
        PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      ],
      appBuilder: (context, slot) => const ExampleApp(),
    ),
  );
}

void main() {
  patrolTest('cart taps and dialogs are mirrored into every device', ($) async {
    await _startPreview($);

    await $(_inDevice(0, ExampleKeys.addProduct('Espresso'))).tap();
    await $(_inDevice(0, ExampleKeys.cart)).tap();

    for (var i = 0; i < _deviceCount; i++) {
      await $(_inDevice(i, ExampleKeys.cartDialog)).waitUntilVisible();
      expect(
        $.tester.widget<Text>(_inDevice(i, ExampleKeys.cartCount)).data,
        '1 items in your cart.',
      );
    }
    expect(find.byKey(ExampleKeys.cartDialog), findsNWidgets(_deviceCount));
  });

  patrolTest('typing filters every device including large text', ($) async {
    await _startPreview($);

    await $(_inDevice(0, ExampleKeys.search)).enterText('latte');

    for (var i = 0; i < _deviceCount; i++) {
      await $(
        find.descendant(
          of: _inDevice(i, ExampleKeys.search),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is EditableText && widget.controller.text == 'latte',
          ),
        ),
      ).waitUntilVisible();
      await $(_inDevice(i, ExampleKeys.product('Matcha latte')))
          .waitUntilVisible();
      final input = find.descendant(
        of: _inDevice(i, ExampleKeys.search),
        matching: find.byType(EditableText),
      );
      expect($.tester.widget<EditableText>(input).controller.text, 'latte');
      expect(_inDevice(i, ExampleKeys.product('Espresso')), findsNothing);
    }
  });

  patrolTest('sync can be disabled and restart resets all devices', ($) async {
    await _startPreview($);

    await $(_sync).tap();
    await $(_inDevice(0, ExampleKeys.ordersTab)).tap();
    await $(_inDevice(0, ExampleKeys.ordersEmpty)).waitUntilVisible();
    for (var i = 1; i < _deviceCount; i++) {
      await $(_inDevice(i, ExampleKeys.search)).waitUntilVisible();
      expect(_inDevice(i, ExampleKeys.ordersEmpty).hitTestable(), findsNothing);
    }

    await $(_restart).tap();
    for (var i = 0; i < _deviceCount; i++) {
      await $(_inDevice(i, ExampleKeys.search)).waitUntilVisible();
    }
    await $(_sync).tap();
    await $(_inDevice(0, ExampleKeys.ordersTab)).tap();

    for (var i = 0; i < _deviceCount; i++) {
      await $(_inDevice(i, ExampleKeys.ordersEmpty)).waitUntilVisible();
    }
    expect($.tester.widget<Switch>(find.byKey(_sync)).value, isTrue);
  });
}
