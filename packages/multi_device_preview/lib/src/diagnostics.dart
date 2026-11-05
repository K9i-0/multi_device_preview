import 'package:flutter/foundation.dart';

/// Where [withSharedGlobalKeyHint] points to.
const String requirementsUrl =
    'https://pub.dev/packages/multi_device_preview#requirements-for-your-app';

final RegExp _keyPattern = RegExp(
  r'\[(?:Labeled)?Global(?:Object)?Key[^\]]*\]',
);

/// Wraps [next] so that the first error about a GlobalKey used by more than
/// one widget explains why that happens in the preview and how to fix it.
///
/// Every device runs in the same process, so a GlobalKey held in a global
/// variable or a static field is shared by all of them, and Flutter reports
/// the same error again on every frame. The hint is printed once per key;
/// the error itself is still passed on to [next].
@internal
FlutterExceptionHandler withSharedGlobalKeyHint(
  FlutterExceptionHandler? next, {
  void Function(String message) printHint = _printHint,
}) {
  final explained = <String>{};
  return (details) {
    final exception = details.exception;
    // A GlobalKey that moves a subtree from one device into another (a
    // shared go_router navigatorKey does) is not reported as a duplicate;
    // Riverpod notices the move instead.
    if ('$exception'.contains(
          'ProviderScope was rebuilt with a different ProviderScope ancestor',
        ) &&
        explained.add('ProviderScope')) {
      printHint(sharedGlobalKeyHint(const []));
    }
    if (exception is FlutterError) {
      final message = exception.message;
      if (message.startsWith('Multiple widgets used the same GlobalKey') ||
          message.startsWith('Duplicate GlobalKey')) {
        final keys = {
          for (final match in _keyPattern.allMatches(message)) match[0]!,
        }.where(explained.add).toList();
        if (keys.isNotEmpty) {
          printHint(sharedGlobalKeyHint(keys));
        }
      }
    }
    (next ?? FlutterError.presentError)(details);
  };
}

/// The explanation printed for [keys], or for a subtree moved between
/// devices when [keys] is empty.
@internal
String sharedGlobalKeyHint(List<String> keys) {
  final which = switch (keys) {
    [] =>
      'A ProviderScope moved to another device. That happens when a '
          'GlobalKey above\nit is',
    [final key] => 'The GlobalKey $key is',
    _ => 'The GlobalKeys ${keys.join(', ')} are',
  };
  return '''
multi_device_preview: $which used by more than one device.
All devices run in one process, so a GlobalKey held in a global variable or a
static field is shared by every device. Common ones are a go_router
navigatorKey (and the parentNavigatorKey of typed routes) and a MaterialApp
scaffoldMessengerKey. Create the key once per app instance instead, for
example where the router is created, or, for something that must exist only
once (like slang's TranslationProvider), place it above all devices with the
wrapper of runMultiDevicePreview.
See $requirementsUrl''';
}

void _printHint(String message) => debugPrint(message);
