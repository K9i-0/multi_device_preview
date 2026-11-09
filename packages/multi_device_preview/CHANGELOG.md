## 1.3.1

- The closed iPhone Duo (`MultiDevicePresets.iPhoneDuo`) cuts its camera as
  a 37 pt circle at the top of the right control strip, above the time, as
  the iOS 27.2 simulator does. It was a pill at the top center, which hid
  app content that the device shows.

## 1.3.0

- Keyboard focus stays on the first device while input is mirrored. Every
  app focuses its first route when it starts, so the device that started
  last held the focus and keyboard shortcuts above the app's `Navigator`
  (for example a debug menu on Shift+D) only worked there; focus dropped
  after a mirrored tap reached no device at all.
- Outside release mode, `runMultiDevicePreview` explains the first
  `Multiple widgets used the same GlobalKey` error for each key, and
  Riverpod's `ProviderScope was rebuilt with a different ProviderScope
  ancestor`: a GlobalKey in a global variable or a static field (a go_router
  `navigatorKey`, a `scaffoldMessengerKey`) is shared by every device. The
  README lists these cases.
- `init` looks through the widgets wrapping the app as `child:` in
  `runApp`, for example `ProviderScope(overrides: ..., child:
  TranslationProvider(child: MyApp()))`: it builds a `ProviderScope` in
  `appBuilder` (and adds Riverpod to a host app) and lists the other
  wrappers in a comment, instead of leaving only TODOs.
- The entry point written by `init` passes the devices to a
  `MultiDevicePreviewController`, so multi_device_preview_marionette can be
  added to it as is.
- `init --host` in a pub workspace: the host app uses the workspace's
  `analysis_options.yaml` instead of flutter_lints, and the `pubspec.lock`
  left by `flutter create` is removed. `init` reminds you to add the
  packages the entry point imports to the host app.

## 1.2.0

- `PreviewDevice.orientation`: a device can be held in landscape. The screen
  size is swapped, the preset's landscape safe areas are used and the frame
  is rotated, as device_preview does. `captureScreen` and `saveScreenshot`
  with `frame=false` save the landscape size (2752×2064 for the iPad Pro 13"
  M5). The device sheet has a Portrait / Landscape choice, `setDevice` and
  `addDevice` take an `orientation` parameter (`portrait` or `landscape`) and
  `getState` reports each device's orientation.
- `PreviewDevice.copyWith`.
- `MultiDevicePresets.iPhoneDuo` (closed) uses the safe areas of the iOS 27.2
  simulator: right 84 and bottom 34 with no top inset in portrait, left 84
  and bottom 34 in landscape. Its status bar is drawn at the top of the right
  strip, like the open one, instead of along the top, at the height measured
  on the outer display (the time 87 pt from the top).
  `MultiDevicePresets.iPhoneDuoOpen` held in the other orientation (the inner
  display upright, 669×951) uses the simulator's top 82 and bottom 34.
- `runMultiDevicePreview` asserts when both `devices` and `controller` are
  given: the devices of the controller are used, so `devices` was silently
  ignored.
- `init --host` also links asset files listed directly in the app's root
  (for example `- shorebird.yaml`) into the host app. Only top-level
  directories were linked, so the host build could not find such files.

## 1.1.0

- `MultiDevicePresets` with the iPhone Duo, closed (`apple-iphone-duo`) and
  open (`apple-iphone-duo-open`). They are offered in the device sheet,
  `listPresets` and `setDevice` / `addDevice`. The open one draws its status
  bar in the right safe area, as the iOS simulator does.
- `MultiDevicePreviewController.captureScreen` and `saveScreenshot` with
  `frame=false` save one device's screen for App Store Connect: no frame, at
  the device pixel ratio, without an alpha channel.
- `statusBarTime` on `runMultiDevicePreview` and `MultiDevicePreview` sets the
  time in every simulated status bar. It defaults to `9:41` instead of the
  `5:13` of device_preview's artwork.

## 1.0.0

First release.

- `runMultiDevicePreview` and `MultiDevicePreview` run one instance of the app
  per device, side by side in a single macOS window, with device_preview
  frames, per-device screen size, safe areas and text scale, scaled to fit.
- Input sync: pointer input on the first device (taps, long presses, drags,
  mouse wheel, trackpad) is mirrored to the other devices by matching
  elements (keys, semantics, images, text, input fields). Imprecise taps are
  not sent and mark the device as out of sync.
- Input fields and Enter submissions are mirrored; focus stays on the first
  device.
- Toolbar to toggle sync, restart every app and add devices; per-device sheet
  to switch the preset and text scale while keeping the app state.
- The simulated status bar follows each app's `SystemUiOverlayStyle`.
- `MultiDevicePreviewController` to drive the preview from code, including
  PNG screenshots.
- `previewCommands`, also exposed as VM service extensions, for tools and AI
  agents.
- `dart run multi_device_preview:init` sets up an entry point in the app, or a
  separate host app with `--host`.
