/// Run a Flutter app on multiple device sizes and text scales side by side in
/// a single macOS window, and mirror input on one device to the others.
library;

export 'package:device_preview/presets.dart' show DevicePreset, DevicePresets;

export 'src/controller.dart'
    show MultiDevicePreviewController, defaultPreviewDevices;
export 'src/multi_device_preview.dart'
    show MultiDeviceAppBuilder, MultiDevicePreview;
export 'src/preview_device.dart' show DeviceSlot, PreviewDevice;
export 'src/run.dart' show runMultiDevicePreview;
export 'src/sync/anchor.dart' show Anchor, AnchorResolver, imageProviderSource;
