import 'dart:io';

import 'package:multi_device_preview/src/init/init.dart';

/// `dart run multi_device_preview:init [--host <dir>]`
Future<void> main(List<String> arguments) async {
  exitCode = await runInit(arguments);
}
