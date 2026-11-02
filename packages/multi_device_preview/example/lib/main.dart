import 'package:multi_device_preview/multi_device_preview.dart';

import 'app.dart';

void main() {
  runMultiDevicePreview(
    devices: const [
      PreviewDevice(preset: DevicePresets.iPhone17),
      PreviewDevice(preset: DevicePresets.iPhoneSe3),
      PreviewDevice(preset: DevicePresets.iPhoneSe3, textScale: 1.5),
      PreviewDevice(preset: DevicePresets.pixel9),
    ],
    appBuilder: (context, slot) => const ExampleApp(),
  );
}
