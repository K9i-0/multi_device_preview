// The `init` command. Runs on the Dart VM, so nothing here may import
// Flutter.
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// The entry point created in the app for method A.
const String defaultEntryPoint = 'multi_device_preview/main.dart';

/// Entitlements the macOS debug build needs. The sandbox is turned off: this
/// is a development tool, and local mock servers and the Keychain then work
/// without extra setup.
const Map<String, bool> requiredEntitlements = {
  'com.apple.security.app-sandbox': false,
  'com.apple.security.cs.allow-jit': true,
  'com.apple.security.network.client': true,
  'com.apple.security.network.server': true,
};

/// Runs the command with [arguments] in [workingDirectory]. Returns the exit
/// code.
Future<int> runInit(
  List<String> arguments, {
  String? workingDirectory,
  IOSink? out,
  ProcessRunner runProcess = defaultProcessRunner,
}) async {
  final sink = out ?? stdout;
  final parser = ArgParser()
    ..addOption(
      'host',
      help:
          'Create a separate host app in this directory (method B), instead '
          'of adding an entry point to the app (method A).',
      valueHelp: 'dir',
    )
    ..addOption(
      'entry',
      help: 'Where to create the entry point, for method A.',
      defaultsTo: defaultEntryPoint,
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Overwrite an existing entry point.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    sink.writeln(error.message);
    sink.writeln(_usage(parser));
    return 64;
  }
  if (args.flag('help')) {
    sink.writeln(_usage(parser));
    return 0;
  }

  final appDir = p.normalize(
    p.absolute(workingDirectory ?? Directory.current.path),
  );
  final AppInfo app;
  try {
    app = AppInfo.read(appDir);
  } on InitException catch (error) {
    sink.writeln(error.message);
    return 1;
  }

  try {
    final host = args.option('host');
    if (host == null) {
      await initEntryPoint(
        app,
        entry: args.option('entry')!,
        force: args.flag('force'),
        out: sink,
        runProcess: runProcess,
      );
    } else {
      await initHostApp(
        app,
        hostDir: p.normalize(p.join(appDir, host)),
        out: sink,
        runProcess: runProcess,
      );
    }
  } on InitException catch (error) {
    sink.writeln(error.message);
    return 1;
  }
  return 0;
}

String _usage(ArgParser parser) => '''
Sets up multi_device_preview for the Flutter app in the current directory.

  dart run multi_device_preview:init              Method A: add an entry point
  dart run multi_device_preview:init --host ../x  Method B: create a host app

${parser.usage}''';

/// A failure explained to the user.
class InitException implements Exception {
  /// Creates an exception with [message].
  const InitException(this.message);

  /// What went wrong and how to fix it.
  final String message;

  @override
  String toString() => message;
}

/// Runs an external command, returning its exit code.
typedef ProcessRunner = Future<int> Function(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
});

/// Runs a command, forwarding its output.
Future<int> defaultProcessRunner(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}

/// What `init` needs to know about the app under preview.
class AppInfo {
  AppInfo._(this.dir, this.pubspec, this.rootWidget);

  /// Reads the app in [dir].
  factory AppInfo.read(String dir) {
    final file = File(p.join(dir, 'pubspec.yaml'));
    if (!file.existsSync()) {
      throw InitException(
        'No pubspec.yaml in $dir. Run this from the root of your Flutter app.',
      );
    }
    final pubspec = loadYaml(file.readAsStringSync());
    if (pubspec is! YamlMap || pubspec['name'] is! String) {
      throw InitException('Could not read the name in ${file.path}.');
    }
    final dependencies = pubspec['dependencies'];
    if (dependencies is! YamlMap || dependencies['flutter'] == null) {
      throw InitException('${file.path} is not a Flutter app.');
    }
    return AppInfo._(dir, pubspec, findRootWidget(dir));
  }

  /// The app directory.
  final String dir;

  /// The parsed pubspec.
  final YamlMap pubspec;

  /// The widget passed to `runApp`, if it could be found.
  final RootWidget? rootWidget;

  /// The package name.
  String get name => pubspec['name'] as String;

  /// Whether the app is a member of a pub workspace.
  bool get inWorkspace => pubspec['resolution'] == 'workspace';

  /// How the app depends on multi_device_preview, as a pubspec value for a
  /// package in [fromDir]: the same version constraint, or the same path
  /// rebased onto [fromDir].
  Object previewDependency(String fromDir) {
    for (final section in ['dev_dependencies', 'dependencies']) {
      final deps = pubspec[section];
      if (deps is! YamlMap || !deps.containsKey('multi_device_preview')) {
        continue;
      }
      final spec = _plain(deps['multi_device_preview']);
      if (spec is Map && spec['path'] is String) {
        final path = spec['path'] as String;
        final absolute = p.normalize(
          p.isAbsolute(path) ? path : p.join(dir, path),
        );
        return {
          ...spec,
          'path': p.posix.joinAll(p.split(p.relative(absolute, from: fromDir))),
        };
      }
      if (spec != null) {
        return spec;
      }
    }
    return '^1.0.0';
  }

  /// How the app depends on [package] in its `dependencies`, as a pubspec
  /// value, or null. A path is rebased onto [fromDir] when given.
  Object? dependency(String package) {
    final deps = pubspec['dependencies'];
    if (deps is! YamlMap || !deps.containsKey(package)) {
      return null;
    }
    return _plain(deps[package]);
  }

  /// The `flutter` section of the pubspec.
  YamlMap? get flutterSection {
    final section = pubspec['flutter'];
    return section is YamlMap ? section : null;
  }
}

/// The widget an app passes to `runApp`, and the library declaring it.
class RootWidget {
  /// Describes a root widget.
  const RootWidget(
    this.expression,
    this.library, {
    this.wrappers = const [],
    this.riverpodImport,
  });

  /// The innermost widget passed to `runApp`, for example `const MyApp()`.
  final String expression;

  /// The library path inside `lib/` that declares the widget class.
  final String library;

  /// The widgets `main()` wraps [expression] in, outermost first, for
  /// example `ProviderScope` and slang's `TranslationProvider`.
  final List<String> wrappers;

  /// The directive importing Riverpod in `lib/main.dart`, when [wrappers]
  /// has a `ProviderScope`.
  final String? riverpodImport;

  /// The package [riverpodImport] imports.
  String? get riverpodPackage => riverpodImport == null
      ? null
      : RegExp('package:(\\w+)/').firstMatch(riverpodImport!)?.group(1);
}

/// Finds `runApp(<expression>)` in `lib/main.dart` and the library declaring
/// the widget class it creates.
///
/// Wrappers that take the app as `child:` (for example
/// `ProviderScope(overrides: ..., child: MyApp())`) are looked through. The
/// innermost widget must be created without arguments, since anything it is
/// given comes from `main()`.
RootWidget? findRootWidget(String appDir) {
  final main = File(p.join(appDir, 'lib', 'main.dart'));
  if (!main.existsSync()) {
    return null;
  }
  final source = main.readAsStringSync();
  final call = RegExp(r'\brunApp\(').firstMatch(source);
  if (call == null) {
    return null;
  }
  var expression = _balanced(source, call.end - 1);
  if (expression == null) {
    return null;
  }
  final wrappers = <String>[];
  RegExpMatch? leaf;
  final creation = RegExp(r'^(const\s+)?([A-Z]\w*)\s*(?:<[^>()]*>)?\s*\(');
  while (true) {
    expression = expression!.trim();
    if (expression.endsWith(',')) {
      expression = expression.substring(0, expression.length - 1).trim();
    }
    final match = creation.firstMatch(expression);
    if (match == null) {
      return null;
    }
    final arguments = _balanced(expression, match.end - 1);
    if (arguments == null) {
      return null;
    }
    if (arguments.trim().isEmpty || arguments.trim() == ',') {
      leaf = match;
      break;
    }
    final child = _namedArgument(arguments, 'child');
    if (child == null) {
      return null;
    }
    wrappers.add(match[2]!);
    expression = child;
  }
  final className = leaf[2]!;
  final declaration = RegExp('class\\s+$className\\b');
  final lib = Directory(p.join(appDir, 'lib'));
  final candidates =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in candidates) {
    if (declaration.hasMatch(file.readAsStringSync())) {
      return RootWidget(
        '${leaf[1] == null ? '' : 'const '}$className()',
        p.posix.joinAll(p.split(p.relative(file.path, from: lib.path))),
        wrappers: wrappers,
        riverpodImport: wrappers.contains('ProviderScope')
            ? RegExp(
                r"import\s+'package:(?:flutter_riverpod|hooks_riverpod|riverpod)"
                r"/[^']+'\s*;",
              ).firstMatch(source)?.group(0)
            : null,
      );
    }
  }
  return null;
}

/// The text between the parenthesis at [open] in [source] and the one
/// closing it, or null when it is not closed.
String? _balanced(String source, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (quote != null) {
      if (char == r'\') {
        i++;
      } else if (source.startsWith(quote, i)) {
        i += quote.length - 1;
        quote = null;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      quote = source.startsWith(char * 3, i) ? char * 3 : char;
      i += quote.length - 1;
    } else if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(open + 1, i);
      }
    }
  }
  return null;
}

/// The value of the top-level named argument [name] in [arguments].
String? _namedArgument(String arguments, String name) {
  var depth = 0;
  var start = 0;
  final parts = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    final char = arguments[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      depth--;
    } else if (char == ',' && depth == 0) {
      parts.add(arguments.substring(start, i));
      start = i + 1;
    }
  }
  parts.add(arguments.substring(start));
  for (final part in parts) {
    final match = RegExp('^\\s*$name\\s*:').firstMatch(part);
    if (match != null) {
      return part.substring(match.end);
    }
  }
  return null;
}

/// The Dart source of a preview entry point for [app].
String entryPointSource(AppInfo app) {
  final root = app.rootWidget;
  final imports = <String>[
    "import 'package:multi_device_preview/multi_device_preview.dart';",
  ];
  final notes = StringBuffer();
  String builder;
  if (root == null) {
    imports.add(
      "// TODO: import your app's root widget.\n"
      "// import 'package:${app.name}/app.dart';",
    );
    builder =
        "// TODO: build your app's root widget, as in main().\n"
        '    appBuilder: (context, slot) => throw UnimplementedError(),';
  } else {
    imports.add("import 'package:${app.name}/${root.library}';");
    var widget = root.expression;
    final others = [...root.wrappers];
    if (root.riverpodImport case final riverpod?) {
      imports.add(riverpod);
      others.remove('ProviderScope');
      widget = widget.startsWith('const ')
          ? 'const ProviderScope(child: ${widget.substring(6)})'
          : 'ProviderScope(child: $widget)';
    }
    if (root.wrappers.isNotEmpty) {
      notes
        ..writeln('//')
        ..writeln(
          '// main() wraps the app in ${root.wrappers.join(' > ')}. Pass '
          'them what',
        )
        ..writeln(
          '// main() passes them (for example the overrides of '
          'ProviderScope).',
        );
      if (others.isNotEmpty) {
        notes
          ..writeln(
            '// TODO: add ${others.join(', ')}: in appBuilder when each '
            'device needs its',
          )
          ..writeln(
            "// own, or once in runMultiDevicePreview's wrapper when it "
            'must exist only',
          )
          ..writeln(
            "// once (like slang's TranslationProvider, which holds a "
            'global key).',
          );
      }
    }
    builder = 'appBuilder: (context, slot) => $widget,';
  }
  imports.sort((a, b) => a.startsWith('//') ? 1 : a.compareTo(b));
  return '''
// Runs the app on several devices side by side, with input mirrored from the
// first device to the others:
//
//   flutter run -d macos -t <this file>
//
// Initialize what main() initializes (shared by every device) before
// runMultiDevicePreview. appBuilder is called once per device, so each device
// gets its own state (for example its own ProviderScope).
$notes${imports.join('\n')}

void main() {
  // The controller also changes devices and takes screenshots from code, and
  // is what multi_device_preview_marionette needs.
  final controller = MultiDevicePreviewController(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      PreviewDevice(preset: DevicePresets.pixel9),
    ],
  );
  runMultiDevicePreview(
    controller: controller,
    $builder
  );
}
''';
}

/// Method A: adds a macOS target (if missing), an entry point and the
/// entitlements to [app].
Future<void> initEntryPoint(
  AppInfo app, {
  String entry = defaultEntryPoint,
  bool force = false,
  required IOSink out,
  ProcessRunner runProcess = defaultProcessRunner,
}) async {
  await _ensureMacOS(app.dir, out, runProcess);

  final entryFile = File(p.join(app.dir, entry));
  if (entryFile.existsSync() && !force) {
    out.writeln('Kept the existing $entry (use --force to overwrite).');
  } else {
    entryFile.parent.createSync(recursive: true);
    entryFile.writeAsStringSync(entryPointSource(app));
    out.writeln('Created $entry.');
  }
  if (app.rootWidget == null) {
    out.writeln(
      'Could not find the widget passed to runApp in lib/main.dart; fill in '
      'the TODOs in $entry.',
    );
  }
  if (app.rootWidget?.wrappers.isNotEmpty ?? false) {
    out.writeln(
      'main() wraps the app in ${app.rootWidget!.wrappers.join(' > ')}; '
      'complete $entry.',
    );
  }
  _patchEntitlements(app.dir, out);

  final deps = app.pubspec['dev_dependencies'];
  final declared =
      deps is YamlMap && deps.containsKey('multi_device_preview') ||
      (app.pubspec['dependencies'] as YamlMap).containsKey(
        'multi_device_preview',
      );
  if (!declared) {
    out.writeln(
      'Add multi_device_preview to dev_dependencies: '
      'flutter pub add dev:multi_device_preview',
    );
  }
  out
    ..writeln()
    ..writeln('Run it with:')
    ..writeln('  flutter run -d macos -t $entry');
}

/// Method B: creates a separate host app in [hostDir] that depends on [app]
/// and runs it in the preview.
Future<void> initHostApp(
  AppInfo app, {
  required String hostDir,
  required IOSink out,
  ProcessRunner runProcess = defaultProcessRunner,
}) async {
  final hostName = '${app.name}_preview';
  final hostPubspec = File(p.join(hostDir, 'pubspec.yaml'));
  if (!hostPubspec.existsSync()) {
    final code = await runProcess('flutter', [
      'create',
      '--no-pub',
      '--empty',
      '--platforms=macos',
      '--project-name',
      hostName,
      hostDir,
    ], workingDirectory: app.dir);
    if (code != 0 || !hostPubspec.existsSync()) {
      throw InitException('flutter create failed (exit code $code).');
    }
  } else {
    await _ensureMacOS(hostDir, out, runProcess);
  }

  final relativeApp = p.posix.joinAll(
    p.split(p.relative(app.dir, from: hostDir)),
  );
  final editor = YamlEditor(hostPubspec.readAsStringSync());
  editor.update(['dependencies', app.name], {'path': relativeApp});
  editor.update([
    'dependencies',
    'multi_device_preview',
  ], app.previewDependency(hostDir));
  if (app.rootWidget?.riverpodPackage case final riverpod?) {
    if (app.dependency(riverpod) case final spec?) {
      editor.update(['dependencies', riverpod], spec);
    }
  }
  final workspaceRoot = app.inWorkspace ? _workspaceRoot(app.dir) : null;
  if (app.inWorkspace) {
    editor.update(['resolution'], 'workspace');
  }
  // In a workspace, the host follows the workspace's lints instead of the
  // flutter_lints that `flutter create` sets up.
  final workspaceLints =
      workspaceRoot != null &&
      File(p.join(workspaceRoot, 'analysis_options.yaml')).existsSync();
  if (workspaceLints) {
    final devDependencies = editor.parseAt([
      'dev_dependencies',
    ], orElse: () => wrapAsYamlNode(null));
    if (devDependencies is YamlMap &&
        devDependencies.containsKey('flutter_lints')) {
      if (devDependencies.length == 1) {
        editor.remove(['dev_dependencies']);
      } else {
        editor.remove(['dev_dependencies', 'flutter_lints']);
      }
    }
  }
  final flutter = app.flutterSection;
  final linked = <String>{};
  for (final section in ['assets', 'fonts']) {
    final value = flutter?[section];
    if (value is YamlList && value.isNotEmpty) {
      _ensureMap(editor, ['flutter']);
      editor.update(['flutter', section], _plain(value));
      linked.addAll(_assetRoots(value));
    }
  }
  if (flutter?['uses-material-design'] == true) {
    _ensureMap(editor, ['flutter']);
    editor.update(['flutter', 'uses-material-design'], true);
  }
  hostPubspec.writeAsStringSync(editor.toString());
  out.writeln('Updated ${p.relative(hostPubspec.path, from: app.dir)}.');
  if (workspaceLints) {
    final options = File(p.join(hostDir, 'analysis_options.yaml'));
    if (options.existsSync() &&
        options.readAsStringSync().contains('package:flutter_lints/')) {
      options.deleteSync();
      out.writeln(
        "Removed the host's analysis_options.yaml to use the "
        "workspace's.",
      );
    }
  }
  if (app.inWorkspace) {
    // A workspace member resolves in the workspace root; pub would delete
    // this lock file anyway.
    final lock = File(p.join(hostDir, 'pubspec.lock'));
    if (lock.existsSync()) {
      lock.deleteSync();
    }
  }

  // Assets of a dependency resolve under packages/<name>/, while the app
  // loads them without a package. Linking the directories into the host
  // makes the same paths resolve there.
  for (final root in linked) {
    final link = Link(p.join(hostDir, root));
    final target = p.relative(p.join(app.dir, root), from: hostDir);
    if (link.existsSync()) {
      if (link.targetSync() != target) {
        out.writeln(
          'Kept $root in the host app, which is not a link to $target.',
        );
      }
      continue;
    }
    if (FileSystemEntity.typeSync(link.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      out.writeln('Kept $root in the host app; link it to $target manually.');
      continue;
    }
    link.createSync(target);
    out.writeln('Linked $root -> $target.');
  }

  final main = File(p.join(hostDir, 'lib', 'main.dart'));
  main.parent.createSync(recursive: true);
  main.writeAsStringSync(entryPointSource(app));
  out.writeln('Wrote ${p.relative(main.path, from: app.dir)}.');
  _patchEntitlements(hostDir, out);

  if (app.rootWidget?.wrappers.isNotEmpty ?? false) {
    out.writeln(
      'main() wraps the app in ${app.rootWidget!.wrappers.join(' > ')}; '
      'complete lib/main.dart of the host app.',
    );
  }
  out
    ..writeln(
      'Add the packages lib/main.dart imports to the dependencies of '
      '${p.relative(hostPubspec.path, from: app.dir)}.',
    )
    ..writeln();
  if (app.inWorkspace) {
    out.writeln(
      'Add ${p.relative(hostDir, from: workspaceRoot ?? app.dir)} '
      'to the workspace list of your root pubspec.yaml, then:',
    );
  } else {
    out.writeln('Then:');
  }
  out
    ..writeln('  cd ${p.relative(hostDir, from: app.dir)}')
    ..writeln('  flutter pub get')
    ..writeln('  flutter run -d macos');
}

Future<void> _ensureMacOS(
  String dir,
  IOSink out,
  ProcessRunner runProcess,
) async {
  if (Directory(p.join(dir, 'macos')).existsSync()) {
    return;
  }
  out.writeln('Adding the macOS platform...');
  final code = await runProcess('flutter', [
    'create',
    '--no-pub',
    '--platforms=macos',
    '.',
  ], workingDirectory: dir);
  if (code != 0) {
    throw InitException('flutter create failed (exit code $code).');
  }
}

void _patchEntitlements(String dir, IOSink out) {
  final file = File(
    p.join(dir, 'macos', 'Runner', 'DebugProfile.entitlements'),
  );
  if (!file.existsSync()) {
    out.writeln('No ${p.relative(file.path, from: dir)}; skipped.');
    return;
  }
  final original = file.readAsStringSync();
  final patched = patchEntitlements(original);
  if (patched == original) {
    out.writeln('Entitlements are already set up.');
    return;
  }
  file.writeAsStringSync(patched);
  out.writeln(
    'Updated ${p.relative(file.path, from: dir)} (sandbox off, network, JIT).',
  );
}

/// Sets [requiredEntitlements] in the plist [source], keeping other keys.
String patchEntitlements(String source) {
  var result = source;
  for (final MapEntry(key: key, value: value) in requiredEntitlements.entries) {
    final tag = value ? '<true/>' : '<false/>';
    final existing = RegExp(
      '(<key>${RegExp.escape(key)}</key>\\s*)<(true|false)\\s*/>',
    );
    if (existing.hasMatch(result)) {
      result = result.replaceFirstMapped(existing, (m) => '${m[1]}$tag');
    } else {
      final end = result.lastIndexOf('</dict>');
      if (end < 0) {
        throw const InitException('Unexpected entitlements file format.');
      }
      result =
          '${result.substring(0, end)}\t<key>$key</key>\n\t$tag\n'
          '${result.substring(end)}';
    }
  }
  return result;
}

void _ensureMap(YamlEditor editor, List<Object> path) {
  final node = editor.parseAt(path, orElse: () => wrapAsYamlNode(null));
  if (node is! YamlMap) {
    editor.update(path, <String, Object?>{});
  }
}

Object? _plain(Object? node) => switch (node) {
  YamlMap() => {
    for (final entry in node.entries) '${entry.key}': _plain(entry.value),
  },
  YamlList() => [for (final item in node) _plain(item)],
  _ => node,
};

/// The top-level directories that the `assets` or `fonts` entries in
/// [section] live in, and the files listed directly in the app's root (for
/// example `shorebird.yaml`).
Set<String> _assetRoots(YamlList section) {
  final paths = <String>[];
  void collect(Object? node) {
    switch (node) {
      case String():
        paths.add(node);
      case YamlMap():
        for (final key in ['path', 'asset']) {
          if (node[key] is String) {
            paths.add(node[key] as String);
          }
        }
        collect(node['fonts']);
      case YamlList():
        node.forEach(collect);
    }
  }

  collect(section);
  return {
    for (final path in paths)
      if (p.posix.split(p.posix.normalize(path)) case [final root, ...]
          when root != '.' && root != '..' && root != '/')
        root,
  };
}

String? _workspaceRoot(String dir) {
  var current = p.dirname(dir);
  while (true) {
    final file = File(p.join(current, 'pubspec.yaml'));
    if (file.existsSync()) {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is YamlMap && yaml['workspace'] != null) {
        return current;
      }
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}
