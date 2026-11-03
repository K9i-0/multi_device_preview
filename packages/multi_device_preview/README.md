# multi_device_preview

> **Note:** multi_device_preview is an independent package by a different
> author. It uses the device frames and presets of
> [device_preview](https://pub.dev/packages/device_preview).

Run your Flutter app on **several device sizes and text scales side by side in
one macOS window**, and **mirror your input on one device to all the others**.
Check overflows and broken layouts on every screen at once, while you use the
app normally.

![Four devices side by side, in sync](https://raw.githubusercontent.com/K9i-0/multi_device_preview/main/packages/multi_device_preview/doc/screenshot.png)

- Each device runs its own instance of your app, with its own state.
- Screen size, safe areas and text scale come from `MediaQuery`, framed with
  device_preview's artwork (iPhone, iPad, Pixel, Galaxy, foldables...), plus
  the iPhone Duo closed and open.
- Taps, long presses, drags, mouse wheel and trackpad scrolls on the first
  device are sent to the others, to the *same element* even when it sits
  elsewhere on a different screen size.
- Text typed into input fields and Enter submissions are mirrored too.
- Switch devices and text scales, restart all apps, or turn syncing off from
  the toolbar.
- Save App Store screenshots of each device at the exact pixel size.
- AI agents can drive it through [Marionette](https://pub.dev/packages/marionette_flutter)
  (see [multi_device_preview_marionette](https://pub.dev/packages/multi_device_preview_marionette)).

This is not a replacement for testing on real devices. Native UI, platform
views (WebView, maps), video and the software keyboard are out of scope.

## Getting started

The preview runs as a **macOS app in debug mode**. There are two ways to set
it up; the API is the same.

| | A. Add an entry point to your app | B. Create a separate host app |
|---|---|---|
| Suits | single-package repositories | monorepos / pub workspaces |
| macOS build | your app's plugins build for macOS | some plugins don't, and you want to override or patch them without touching the app |
| Changes to your app | adds `macos/` and a dev dependency | none |
| Assets and fonts | work as is | re-declared and linked by `init` |

### A. Entry point in your app

```sh
flutter pub add dev:multi_device_preview
dart run multi_device_preview:init
flutter run -d macos -t multi_device_preview/main.dart
```

`init` adds the macOS platform if needed, creates
`multi_device_preview/main.dart` (outside `lib/`, so it never ships in a
release build) and sets the macOS entitlements. Running it again keeps your
edits.

### B. Separate host app

```sh
flutter pub add dev:multi_device_preview
dart run multi_device_preview:init --host ../my_app_preview
cd ../my_app_preview && flutter pub get && flutter run -d macos
```

The host app depends on your app by path. Since your app's assets would
resolve under `packages/my_app/` there, `init` copies the `assets` and `fonts`
declarations to the host and links the asset directories. In a pub workspace,
add the host to the workspace list.

### The entry point

```dart
import 'package:multi_device_preview/multi_device_preview.dart';
import 'package:my_app/app.dart';

void main() {
  // Initialize what main() initializes; it is shared by all devices.
  runMultiDevicePreview(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      PreviewDevice(preset: DevicePresets.pixel9),
    ],
    // Called once per device (and on restart): each device gets its own
    // state, for example its own ProviderScope.
    appBuilder: (context, slot) => const ProviderScope(child: MyApp()),
  );
}
```

Other options of `runMultiDevicePreview`:

- `controller`: a `MultiDevicePreviewController` to change devices, toggle
  sync, restart or capture screenshots from code.
- `wrapper`: wraps the whole preview, for things that must exist only once
  above all devices (for example slang's `TranslationProvider`).
- `targetPlatform`: every device renders as iOS by default (debug mode only).
  Android presets change the size, safe areas and frame.
- `mouseAsTouch`: the mouse acts as a finger (default), so dragging scrolls.
- `anchorResolvers`: see [Matching elements](#matching-elements).
- `statusBarTime`: the time in every simulated status bar. Defaults to
  `9:41`, as in Apple's screenshots.

### Bundled presets

`MultiDevicePresets` adds devices that device_preview does not have yet. They
show up in the device sheet and in `listPresets` next to `DevicePresets`.

| Preset | Id | Screen |
|---|---|---|
| `MultiDevicePresets.iPhoneDuo` | `apple-iphone-duo` | Closed, outer display: 466×678 pt @3x |
| `MultiDevicePresets.iPhoneDuoOpen` | `apple-iphone-duo-open` | Open, inner display in landscape: 951×669 pt @3x |

Their screen outlines come from the iOS simulator (the closed one is barely
rounded on the hinge side); the rest of the frame is a rough outline. The
safe areas of the open state come from the simulator; those of the closed
state are approximate. Like the
simulator, the open state draws its status bar (time, Wi-Fi) in the right
safe area.

### App Store screenshots

`controller.captureScreen(index)` (or `saveScreenshot` with `frame=false`)
saves the screen of one device the way the device itself takes a screenshot:
no frame or rounded corners, at the preset's device pixel ratio, and without
an alpha channel, which App Store Connect rejects. The simulated status bar
and home indicator are kept. The size is the one App Store Connect asks for,
for example 1398×2034 for the closed iPhone Duo and 2853×2007 for the open
one.

```dart
final png = await controller.captureScreen(0);
await File('store/iphone-duo-1.png').writeAsBytes(png);
```

### macOS entitlements

`init` sets these in `macos/Runner/DebugProfile.entitlements`. The sandbox is
off because this is a development tool: local mock servers and the Keychain
work without extra setup.

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

## Input sync

While **Sync input** is on, the first (leftmost) device is the input source:

- Only the first device accepts your pointer input. The others are driven by
  it. (Input injected by Marionette or tests still reaches any device.)
- Each gesture is mapped when it starts and replayed on every other device
  with the original timing, so long presses and flings match.
- When the target is not there yet (page still loading), a device waits up to
  5 seconds. When it is scrolled out of view, it is scrolled into view first.
- Input fields are kept equal to the first device's, by their order on the
  screen. Enter submits on every device for `done`, `go`, `search` and `send`
  actions (`next` is not sent, it would move focus). Enter confirming an IME
  conversion does not submit.
- Focus stays on the first device, so the keyboard keeps typing there.
- Hover is not mirrored.

A **tap that cannot be matched precisely is not sent**: on a screen of another
height, the same relative position could press a different element and take
that device to another page. The device is marked **out of sync** instead
(red outline and label). Drags and scrolls are always sent, since landing in
the same scroll view is enough. Press **Restart** to bring every device back to
the start.

Turning sync off makes every device independent. Gestures that already
started are completed first.

### Matching elements

The same element is found on every device by its landmarks, in this order:

1. `ValueKey<String>`
2. `Semantics` identifier, label or tooltip (`IconButton.tooltip` counts)
3. Image URL or asset name
4. Text
5. Input fields (by their order)

When an element appears several times, the n-th occurrence is used. Taps on
large areas without landmarks (empty space in a page) are not sent, so **the
more keys and semantics your widgets have, the more precise syncing gets**.

Add your own landmarks with `anchorResolvers`, for example for
[extended_image](https://pub.dev/packages/extended_image):

```dart
Anchor? extendedImageAnchor(Element element) {
  final widget = element.widget;
  if (widget is! ExtendedImage) return null;
  final source = switch (widget.image) {
    ExtendedNetworkImageProvider(:final url) => url,
    final provider => imageProviderSource(provider),
  };
  return source == null ? null : Anchor('image', source);
}

runMultiDevicePreview(
  anchorResolvers: [extendedImageAnchor],
  appBuilder: ...,
);
```

## Requirements for your app

All devices run in **one process**, so:

- **No global `GlobalKey`s or singletons holding widget state.** If you have
  one (slang's `TranslationProvider` uses a global key), place it once above
  all devices with `wrapper`.
- **Persisted state is shared**: SharedPreferences, the Keychain and files are
  the same for every device (being signed in, settings).
- **Plugins without a macOS implementation** throw `MissingPluginException`.
  Skip SDKs you don't need for layout checks (analytics, crash reporting, push
  notifications), and guard fire-and-forget calls:

  ```dart
  runZonedGuarded(
    () => runMultiDevicePreview(appBuilder: ...),
    (error, stack) {
      if (error is MissingPluginException) return;
      Zone.current.parent!.handleUncaughtError(error, stack);
    },
  );
  ```

- **Dialogs and bottom sheets just work**, including `rootNavigator: true` and
  `rootOverlay: true`: the tool has no `Navigator` or `Overlay` above the
  devices, so they open inside the device.
- **When `main()` gains new overrides** (for example Riverpod overrides), add
  them to `appBuilder` as well.
- Run it in **debug mode**. Profile mode cannot render as iOS and has no hot
  reload.

## Automation and AI agents

Every action of the toolbar, and more, is available as a command
(`previewCommands`):

| Command | What it does |
|---|---|
| `getState` | Devices (preset, text scale, size, screen key, out-of-sync) and sync state |
| `listPresets` | Preset ids |
| `setSync` | Turns input sync on or off |
| `restart` | Rebuilds every app from scratch |
| `setDevice` / `addDevice` / `removeDevice` | Changes the devices |
| `saveScreenshot` | Writes a PNG of all devices, or one, to a file. `frame=false` writes a store screenshot of one device |
| `panZoom` | Scrolls with a trackpad gesture, mirrored like a real one |

They are registered as VM service extensions
(`ext.multi_device_preview.<command>`) in debug and profile mode.

With [Marionette](https://pub.dev/packages/marionette_flutter), add
[multi_device_preview_marionette](https://pub.dev/packages/multi_device_preview_marionette)
to get them as MCP tools. Tips for agents:

- Each device screen has the key `multi_device_preview.screen.<n>`. Pass it in
  `ancestor_keys` to look at, or act on, one device. Without it, keys and texts
  match the first device, and the action is mirrored to the others.
- Use `saveScreenshot` instead of `take_screenshots` for the whole window:
  four devices easily exceed the size of an MCP response.
- macOS stops rendering a window hidden behind other windows. Input is still
  handled, but screenshots would be stale, so `saveScreenshot` fails instead.
- Screenshot pixels are not logical coordinates. To act by position, use the
  `bounds` reported by Marionette: `x`/`y` are positions in the (scaled)
  window, `width`/`height` are logical sizes inside the device.
- Marionette's `swipe` is a touch drag. Use `panZoom` to test the trackpad
  path.

## How it compares

- [device_preview](https://pub.dev/packages/device_preview) shows one device
  at a time and switches between them. multi_device_preview runs several at
  once and syncs input between them by matching elements.
- [multi_app_viewer](https://pub.dev/packages/multi_app_viewer) also shows an
  app with several configurations and follows a main instance, through
  scripts or broadcast state and events. multi_device_preview needs no
  changes in the app: raw pointer input and input fields are mirrored as is,
  and AI agents can drive it.

## License

MIT
