// Drives the example on a real macOS window and saves screenshots, to check
// input mirroring end to end:
//
//   flutter run -d macos -t smoke/main.dart --dart-define=OUT=/path/to/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_example/app.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/smoke');

Future<void> main() async {
  final controller = MultiDevicePreviewController(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      PreviewDevice(preset: DevicePresets.pixel9),
    ],
  );
  final window = GlobalKey();
  runMultiDevicePreview(
    controller: controller,
    wrapper: (preview) => RepaintBoundary(key: window, child: preview),
    appBuilder: (context, slot) => const ExampleApp(),
  );
  await Directory(_out).create(recursive: true);
  await Future<void>.delayed(const Duration(seconds: 2));

  Future<void> shoot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final png = await controller.captureScreenshot(pixelRatio: 1);
    await File('$_out/$name.png').writeAsBytes(png);
    stdout.writeln('smoke: saved $_out/$name.png');
  }

  Future<void> shootWindow(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final boundary =
        window.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    stdout.writeln('smoke: saved $_out/$name.png');
  }

  var pointer = 100;
  Future<void> tap(Element target) async {
    final box = target.renderObject! as RenderBox;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    pointer++;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: pointer, device: 50, position: position),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: pointer, device: 50, position: position),
    );
  }

  Element? findInSource(bool Function(Element) test) {
    Element? screen;
    void findScreen(Element e) {
      if (e.widget.key == DeviceSlot.screenKeyOf(0)) {
        screen = e;
        return;
      }
      if (screen == null) e.visitChildElements(findScreen);
    }

    WidgetsBinding.instance.rootElement!.visitChildElements(findScreen);
    Element? found;
    void visit(Element e) {
      if (found != null) return;
      if (test(e)) {
        found = e;
        return;
      }
      e.visitChildElements(visit);
    }

    screen?.visitChildElements(visit);
    return found;
  }

  bool text(Element e, String value) =>
      e.widget is RichText &&
      (e.widget as RichText).text.toPlainText() == value;

  await shoot('0-initial');

  await tap(
    findInSource(
      (e) =>
          text(e, 'Add Matcha latte') ||
          e.widget is Tooltip &&
              (e.widget as Tooltip).message == 'Add Matcha latte',
    )!,
  );
  await tap(findInSource((e) => text(e, 'Flat white'))!);
  await shoot('1-detail');

  await tap(findInSource((e) => text(e, 'Back to the menu'))!);
  await Future<void>.delayed(const Duration(milliseconds: 800));
  final field =
      findInSource((e) => e is StatefulElement && e.state is EditableTextState)!
          as StatefulElement;
  (field.state as EditableTextState).userUpdateTextEditingValue(
    const TextEditingValue(
      text: 'latte',
      selection: TextSelection.collapsed(offset: 5),
    ),
    SelectionChangedCause.keyboard,
  );
  await shoot('2-search');
  await shootWindow('3-window');

  // Open the settings sheet of the third device (tool UI, not mirrored).
  Element? label;
  void findLabel(Element e) {
    if (e.widget.key == const ValueKey('multi_device_preview.label.2')) {
      label = e;
    }
    if (label == null) e.visitChildElements(findLabel);
  }

  WidgetsBinding.instance.rootElement!.visitChildElements(findLabel);
  await tap(label!);
  await shootWindow('4-sheet');

  // Store screenshots: the bare screens of an iPhone Duo, closed and open.
  await tap(label!);
  controller
    ..syncEnabled = false
    ..setDevice(0, const PreviewDevice(preset: MultiDevicePresets.iPhoneDuo))
    ..setDevice(
      1,
      const PreviewDevice(preset: MultiDevicePresets.iPhoneDuoOpen),
    );
  await shootWindow('5-duo');
  for (final (index, name) in [(0, '6-duo-store'), (1, '7-duo-open-store')]) {
    final png = await controller.captureScreen(index);
    await File('$_out/$name.png').writeAsBytes(png);
    stdout.writeln('smoke: saved $_out/$name.png');
  }
  await shootWindow('8-duo-after');

  exit(0);
}
