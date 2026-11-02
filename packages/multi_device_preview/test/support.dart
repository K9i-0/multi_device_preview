import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/multi_device_preview.dart';

/// A taller and a shorter device, so positions differ between them.
const tallAndShort = [
  PreviewDevice(preset: DevicePresets.iPhone17ProMax),
  PreviewDevice(preset: DevicePresets.iPhoneSe3),
];

/// Lays out [controller] in a large window and pumps it.
Future<void> pumpPreview(
  WidgetTester tester, {
  required MultiDevicePreviewController controller,
  required MultiDeviceAppBuilder appBuilder,
  bool showToolbar = true,
  List<AnchorResolver> anchorResolvers = const [],
}) async {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiDevicePreview(
      controller: controller,
      appBuilder: appBuilder,
      showToolbar: showToolbar,
      anchorResolvers: anchorResolvers,
    ),
  );
}

/// Pumps long enough for the mirror to resolve and replay queued gestures.
Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Waits for [future], which needs real I/O (files, image encoding) and
/// frames, by alternating real waits with pumps.
Future<T> completeWithRealAsync<T>(
  WidgetTester tester,
  Future<T> future,
) async {
  T? result;
  Object? error;
  var done = false;
  unawaited(
    future.then(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  if (error != null) {
    throw error!;
  }
  if (!done) {
    throw StateError('The future did not complete.');
  }
  return result as T;
}

/// Finds [matching] inside the device at [index].
Finder inDevice(int index, Finder matching) => find.descendant(
  of: find.byKey(DeviceSlot.screenKeyOf(index)),
  matching: matching,
);

/// Sends a tap at [position] as the operating system would, through
/// `PlatformDispatcher.onPointerDataPacket`.
void platformTap(
  WidgetTester tester,
  Offset position, {
  ui.PointerDeviceKind kind = ui.PointerDeviceKind.touch,
}) {
  final view = tester.view;
  ui.PointerData datum(ui.PointerChange change) => ui.PointerData(
    viewId: view.viewId,
    change: change,
    kind: kind,
    device: 7,
    pointerIdentifier: 7,
    physicalX: position.dx * view.devicePixelRatio,
    physicalY: position.dy * view.devicePixelRatio,
    buttons: change == ui.PointerChange.down ? kPrimaryButton : 0,
  );
  tester.binding.platformDispatcher.onPointerDataPacket!(
    ui.PointerDataPacket(
      data: [
        datum(ui.PointerChange.add),
        datum(ui.PointerChange.down),
        datum(ui.PointerChange.up),
        datum(ui.PointerChange.remove),
      ],
    ),
  );
}

/// A counter app with a list, a text field and a dialog.
class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key, this.loadingDelay = Duration.zero});

  /// How long the app shows a loading indicator before its content.
  final Duration loadingDelay;

  @override
  State<ProbeApp> createState() => ProbeAppState();
}

class ProbeAppState extends State<ProbeApp> {
  int count = 0;
  int favorites = 0;
  String? lastItem;
  String changed = '';
  String submitted = '';
  late bool loading = widget.loadingDelay > Duration.zero;

  @override
  void initState() {
    super.initState();
    if (loading) {
      Future<void>.delayed(widget.loadingDelay, () {
        if (mounted) {
          setState(() => loading = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Probe'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Favorite',
              icon: const Icon(Icons.star),
              onPressed: () => setState(() => favorites++),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const ValueKey('list'),
                children: [
                  Text('count $count'),
                  Text('item ${lastItem ?? '-'}'),
                  Text('changed $changed'),
                  Text('submitted $submitted'),
                  TextField(
                    key: const ValueKey('search'),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => changed = value),
                    onSubmitted: (value) => setState(() => submitted = value),
                  ),
                  TextField(
                    key: const ValueKey('next'),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (value) =>
                        setState(() => submitted = 'next $value'),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => count++),
                    child: const Text('Increment'),
                  ),
                  for (var i = 0; i < 40; i++)
                    ListTile(
                      title: Text('Row $i'),
                      onTap: () => setState(() => lastItem = 'Row $i'),
                      onLongPress: () =>
                          setState(() => lastItem = 'long Row $i'),
                    ),
                ],
              ),
      ),
    );
  }
}

/// The state of the probe app on the device at [index].
ProbeAppState probeOf(WidgetTester tester, int index) =>
    tester.state<ProbeAppState>(inDevice(index, find.byType(ProbeApp)));

/// Sends an Enter key press to the focused widget.
Future<void> pressEnter(WidgetTester tester) =>
    tester.sendKeyEvent(LogicalKeyboardKey.enter);
