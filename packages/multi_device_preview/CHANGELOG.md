## Unreleased

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
  strip, like the open one, instead of along the top.
  `MultiDevicePresets.iPhoneDuoOpen` held in the other orientation (the inner
  display upright, 669×951) uses the simulator's top 82 and bottom 34.
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
