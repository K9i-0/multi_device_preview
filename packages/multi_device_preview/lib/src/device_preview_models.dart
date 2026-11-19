// device_preview 3.0.0's main library also exports its binding, whose
// PlatformDispatcher implementation does not compile on Flutter 3.50
// (https://github.com/aloisdeniel/flutter_device_preview/pull/301). This
// package never uses that binding, so it reaches the models and the frame
// widget directly.
// ignore_for_file: implementation_imports
export 'package:device_preview/src/model/device_frame.dart';
export 'package:device_preview/src/model/device_kind.dart';
export 'package:device_preview/src/model/fit_transform.dart';
export 'package:device_preview/src/model/real_device_info.dart';
export 'package:device_preview/src/model/simulation.dart';
export 'package:device_preview/src/model/system_ui.dart';
export 'package:device_preview/src/widgets/device_preview_frame.dart'
    show DevicePreviewFrame, RenderDevicePreviewFrame;
