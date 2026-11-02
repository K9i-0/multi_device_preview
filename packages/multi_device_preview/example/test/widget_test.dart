import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview_example/main.dart';

void main() {
  testWidgets('increments the counter', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Tapped 0 times'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('Tapped 1 times'), findsOneWidget);
  });
}
