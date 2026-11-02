# multi_device_preview_marionette

Lets AI agents drive [multi_device_preview](https://pub.dev/packages/multi_device_preview)
through [Marionette MCP](https://pub.dev/packages/marionette_flutter): every
preview command becomes an MCP tool with a typed schema.

| Tool | What it does |
|---|---|
| `multiDevicePreview.getState` | Devices (preset, text scale, size, screen key, out-of-sync) and sync state |
| `multiDevicePreview.listPresets` | Preset ids |
| `multiDevicePreview.setSync` | Turns input sync on or off |
| `multiDevicePreview.restart` | Rebuilds every app from scratch |
| `multiDevicePreview.setDevice` / `addDevice` / `removeDevice` | Changes the devices |
| `multiDevicePreview.saveScreenshot` | Writes a PNG of all devices, or one, to a file |
| `multiDevicePreview.panZoom` | Scrolls with a trackpad gesture, mirrored like a real one |

## Setup

```sh
flutter pub add dev:multi_device_preview_marionette dev:marionette_flutter
```

In the preview entry point, initialize Marionette **before**
`runMultiDevicePreview`:

```dart
import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:multi_device_preview_marionette/multi_device_preview_marionette.dart';

void main() {
  final controller = MultiDevicePreviewController();
  if (!kReleaseMode) {
    MarionetteBinding.ensureInitialized(
      multiDevicePreviewMarionetteConfiguration,
    );
    registerMultiDevicePreviewMarionetteExtensions(controller);
  }
  runMultiDevicePreview(
    controller: controller,
    appBuilder: (context, slot) => const MyApp(),
  );
}
```

`multiDevicePreviewMarionetteConfiguration` uses `CompactionMode.none`, so
`get_interactive_elements` reports every element and an agent can compare
sizes and text scales across devices. Pass your own `MarionetteConfiguration`
to customize it.

## Tips for agents

- Each device screen has the key `multi_device_preview.screen.<n>`. Pass it in
  `ancestor_keys` to look at, or act on, a single device. Without it, keys and
  texts match the first device, and the action is mirrored to the others
  while input sync is on.
- Prefer `multiDevicePreview.saveScreenshot` over `take_screenshots`: several
  devices easily exceed the size of an MCP response.
- macOS stops rendering a window hidden behind other windows; keep the
  preview window visible, or `saveScreenshot` reports an error.
- `bounds` from Marionette: `x`/`y` are positions in the scaled window,
  `width`/`height` are logical sizes inside the device.

## License

MIT
