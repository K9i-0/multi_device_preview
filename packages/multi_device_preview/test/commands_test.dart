import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

import 'support.dart';

void main() {
  late MultiDevicePreviewController controller;
  late Map<String, PreviewCommand> commands;

  setUp(() {
    controller = MultiDevicePreviewController(devices: tallAndShort);
    commands = {
      for (final command in previewCommands(controller)) command.name: command,
    };
  });
  tearDown(() => controller.dispose());

  test('every command documents itself', () {
    for (final command in commands.values) {
      expect(command.description, isNotEmpty);
      for (final param in command.params) {
        expect(param.description, isNotEmpty);
      }
    }
  });

  test('getState describes the devices', () async {
    controller.markOutOfSync(1);
    final state = await commands['getState']!.run({});
    final devices = state['devices']! as List<Object?>;
    expect(state['syncEnabled'], isTrue);
    expect(devices, hasLength(2));
    expect(devices[1], {
      'index': 1,
      'preset': DevicePresets.iPhoneSe3.id,
      'name': DevicePresets.iPhoneSe3.name,
      'textScale': 1.0,
      'width': DevicePresets.iPhoneSe3.portraitSize.width,
      'height': DevicePresets.iPhoneSe3.portraitSize.height,
      'screenKey': 'multi_device_preview.screen.1',
      'outOfSync': true,
      'isSource': false,
    });
  });

  test('setSync, setDevice, addDevice, removeDevice and restart', () async {
    await commands['setSync']!.run({'enabled': 'false'});
    expect(controller.syncEnabled, isFalse);

    await commands['setDevice']!.run({
      'index': '1',
      'preset': DevicePresets.pixel9.id,
      'textScale': '1.3',
    });
    expect(
      controller.devices[1],
      const PreviewDevice(preset: DevicePresets.pixel9, textScale: 1.3),
    );

    await commands['setDevice']!.run({'index': '1', 'textScale': '2'});
    expect(controller.devices[1].preset, DevicePresets.pixel9);
    expect(controller.devices[1].textScale, 2);

    await commands['addDevice']!.run({'preset': DevicePresets.iPadMini.id});
    expect(controller.devices.last.preset, DevicePresets.iPadMini);

    await commands['removeDevice']!.run({'index': '0'});
    expect(controller.devices, hasLength(2));

    await commands['restart']!.run({});
    expect(controller.generation, 1);
  });

  test('listPresets lists every preset', () async {
    final result = await commands['listPresets']!.run({});
    expect(result['presets'], hasLength(DevicePresets.all.length));
  });

  test('invalid arguments are reported, not thrown as crashes', () async {
    Future<void> expectInvalid(String name, Map<String, String> args) =>
        expectLater(
          commands[name]!.run(args),
          throwsA(isA<PreviewCommandException>()),
        );

    await expectInvalid('setSync', {});
    await expectInvalid('setSync', {'enabled': 'yes'});
    await expectInvalid('setDevice', {'index': '5'});
    await expectInvalid('setDevice', {'index': 'one'});
    await expectInvalid('setDevice', {'index': '0', 'preset': 'nokia-3310'});
    await expectInvalid('setDevice', {'index': '0', 'textScale': '-1'});
    await expectInvalid('addDevice', {});
    await expectInvalid('saveScreenshot', {});

    controller.removeDevice(1);
    await expectInvalid('removeDevice', {'index': '0'});
  });

  testWidgets('saveScreenshot writes a PNG file', (tester) async {
    await pumpPreview(
      tester,
      controller: controller,
      appBuilder: (context, slot) => const ProbeApp(),
    );
    final dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('mdp'),
    );
    addTearDown(() => tester.runAsync(() => dir!.delete(recursive: true)));
    final path = '${dir!.path}/nested/device.png';

    final future = commands['saveScreenshot']!.run({
      'path': path,
      'device': '1',
    });
    final result = await completeWithRealAsync(tester, future);

    expect(result['path'], path);
    final bytes = (await tester.runAsync(() => File(path).readAsBytes()))!;
    expect(bytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('panZoom scrolls like a trackpad and is mirrored', (
    tester,
  ) async {
    await pumpPreview(
      tester,
      controller: controller,
      appBuilder: (context, slot) => const ProbeApp(),
    );
    final position = tester.getCenter(inDevice(0, find.text('Row 3')));

    final future = commands['panZoom']!.run({
      'x': '${position.dx}',
      'y': '${position.dy}',
      'dy': '-200',
      'durationMs': '200',
    });
    await settle(tester, frames: 20);
    await future;

    double offsetOf(int device) => tester
        .state<ScrollableState>(inDevice(device, find.byType(Scrollable)).first)
        .position
        .pixels;
    expect(offsetOf(0), greaterThan(100));
    expect(offsetOf(1), closeTo(offsetOf(0), 1));
  });
}
