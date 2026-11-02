import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/src/init/init.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _entitlements = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
</dict>
</plist>
''';

class _Sink implements IOSink {
  final buffer = StringBuffer();
  @override
  void writeln([Object? object = '']) => buffer.writeln(object);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

late Directory root;

String _write(String path, String content) {
  final file = File(p.join(root.path, path))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
  return file.path;
}

String _read(String path) => File(p.join(root.path, path)).readAsStringSync();

void _createApp() {
  _write('app/pubspec.yaml', '''
name: shop
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  multi_device_preview: ^1.0.0
flutter:
  uses-material-design: true
  assets:
    - assets/images/
  fonts:
    - family: Brand
      fonts:
        - asset: fonts/Brand-Regular.ttf
''');
  _write('app/lib/main.dart', '''
import 'package:flutter/widgets.dart';
import 'src/shop_app.dart';

void main() {
  runApp(const ShopApp());
}
''');
  _write('app/lib/src/shop_app.dart', 'class ShopApp {}');
  _write('app/assets/images/logo.png', 'png');
  _write('app/fonts/Brand-Regular.ttf', 'ttf');
}

/// Pretends to be `flutter create`: creates a macOS runner and, for a new
/// project, a pubspec.
Future<int> _fakeFlutter(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final target = p.join(workingDirectory, arguments.last);
  Directory(p.join(target, 'macos', 'Runner')).createSync(recursive: true);
  File(p.join(target, 'macos', 'Runner', 'DebugProfile.entitlements'))
      .writeAsStringSync(_entitlements);
  final pubspec = File(p.join(target, 'pubspec.yaml'));
  if (!pubspec.existsSync()) {
    final name = arguments[arguments.indexOf('--project-name') + 1];
    pubspec.writeAsStringSync('''
name: $name
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
''');
  }
  return 0;
}

void main() {
  setUp(() => root = Directory.systemTemp.createTempSync('mdp_init'));
  tearDown(() => root.deleteSync(recursive: true));

  group('patchEntitlements', () {
    test('turns the sandbox off and adds the missing keys', () {
      final patched = patchEntitlements(_entitlements);
      expect(
        patched,
        contains('<key>com.apple.security.app-sandbox</key>\n\t<false/>'),
      );
      expect(patched, contains('com.apple.security.network.client'));
      expect(patched, endsWith('</dict>\n</plist>\n'));
    });

    test('is idempotent', () {
      final once = patchEntitlements(_entitlements);
      expect(patchEntitlements(once), once);
    });
  });

  test('finds the root widget and the library declaring it', () {
    _createApp();
    final widget = findRootWidget(p.join(root.path, 'app'))!;
    expect(widget.expression, 'const ShopApp()');
    expect(widget.library, 'src/shop_app.dart');
  });

  test('method A adds macOS, an entry point and entitlements', () async {
    _createApp();
    final out = _Sink();
    final code = await runInit(
      [],
      workingDirectory: p.join(root.path, 'app'),
      out: out,
      runProcess: _fakeFlutter,
    );

    expect(code, 0, reason: out.buffer.toString());
    final entry = _read('app/multi_device_preview/main.dart');
    expect(entry, contains("import 'package:shop/src/shop_app.dart';"));
    expect(entry, contains('appBuilder: (context, slot) => const ShopApp(),'));
    expect(
      _read('app/macos/Runner/DebugProfile.entitlements'),
      contains('<key>com.apple.security.app-sandbox</key>\n\t<false/>'),
    );
    expect(out.buffer.toString(), contains('flutter run -d macos -t'));

    // Running again keeps the edited entry point.
    _write('app/multi_device_preview/main.dart', '// edited');
    await runInit(
      [],
      workingDirectory: p.join(root.path, 'app'),
      out: _Sink(),
      runProcess: _fakeFlutter,
    );
    expect(_read('app/multi_device_preview/main.dart'), '// edited');
  });

  test('method B creates a host app with assets, fonts and links', () async {
    _createApp();
    final out = _Sink();
    final code = await runInit(
      ['--host', '../shop_preview'],
      workingDirectory: p.join(root.path, 'app'),
      out: out,
      runProcess: _fakeFlutter,
    );

    expect(code, 0, reason: out.buffer.toString());
    final pubspec = loadYaml(_read('shop_preview/pubspec.yaml')) as YamlMap;
    expect(pubspec['name'], 'shop_preview');
    expect(pubspec['dependencies']['shop'], {'path': '../app'});
    expect(pubspec['dependencies']['multi_device_preview'], '^1.0.0');
    expect(pubspec['flutter']['assets'], ['assets/images/']);
    expect(pubspec['flutter']['fonts'][0]['family'], 'Brand');
    expect(pubspec['flutter']['uses-material-design'], isTrue);
    expect(
      File(p.join(root.path, 'shop_preview/assets/images/logo.png'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(root.path, 'shop_preview/fonts/Brand-Regular.ttf'))
          .existsSync(),
      isTrue,
    );
    expect(
      _read('shop_preview/lib/main.dart'),
      contains("import 'package:shop/src/shop_app.dart';"),
    );

    // Running again changes nothing.
    final before = _read('shop_preview/pubspec.yaml');
    expect(
      await runInit(
        ['--host', '../shop_preview'],
        workingDirectory: p.join(root.path, 'app'),
        out: _Sink(),
        runProcess: _fakeFlutter,
      ),
      0,
    );
    expect(_read('shop_preview/pubspec.yaml'), before);
  });

  test('method B keeps a path dependency working from the host', () async {
    _createApp();
    _write(
      'app/pubspec.yaml',
      _read('app/pubspec.yaml').replaceFirst(
        'multi_device_preview: ^1.0.0',
        'multi_device_preview:\n    path: ../packages/multi_device_preview',
      ),
    );
    await runInit(
      ['--host', '../tools/shop_preview'],
      workingDirectory: p.join(root.path, 'app'),
      out: _Sink(),
      runProcess: _fakeFlutter,
    );
    final pubspec =
        loadYaml(_read('tools/shop_preview/pubspec.yaml')) as YamlMap;
    expect(pubspec['dependencies']['multi_device_preview'], {
      'path': '../../packages/multi_device_preview',
    });
    expect(pubspec['dependencies']['shop'], {'path': '../../app'});
  });

  test('explains what is wrong outside a Flutter app', () async {
    final out = _Sink();
    expect(await runInit([], workingDirectory: root.path, out: out), 1);
    expect(out.buffer.toString(), contains('No pubspec.yaml'));
  });
}
