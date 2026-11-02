import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_example/app.dart';

void main() {
  testWidgets('the app filters the menu', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.enterText(find.byKey(const ValueKey('search')), 'latte');
    await tester.pump();

    expect(find.text('Matcha latte'), findsOneWidget);
    expect(find.text('Espresso'), findsNothing);
  });

  testWidgets('a tap on the first device reaches every device', (tester) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = MultiDevicePreviewController(
      devices: const [
        PreviewDevice(preset: DevicePresets.iPhone17),
        PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MultiDevicePreview(
        controller: controller,
        appBuilder: (context, slot) => const ExampleApp(),
      ),
    );

    await tester.tap(
      find
          .descendant(
            of: find.byKey(DeviceSlot.screenKeyOf(0)),
            matching: find.text('Orders'),
          )
          .first,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final device in [0, 1]) {
      expect(
        find.descendant(
          of: find.byKey(DeviceSlot.screenKeyOf(device)),
          matching: find.text('No orders yet').hitTestable(),
        ),
        findsOneWidget,
      );
    }
  });
}
