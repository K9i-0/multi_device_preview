import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_device_preview/src/png.dart';

void main() {
  test('encodes an RGB PNG that decodes to the same pixels', () async {
    const width = 3;
    const height = 2;
    final rgba = Uint8List.fromList([
      for (var i = 0; i < width * height; i++) ...[i * 40, 255 - i * 40, i, 7],
    ]);

    final png = encodeOpaquePng(rgba, width, height);

    final header = ByteData.sublistView(png, 16, 26);
    expect(header.getUint32(0), width);
    expect(header.getUint32(4), height);
    expect(header.getUint8(9), 2, reason: 'truecolor without alpha');

    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final decoded = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    for (var i = 0; i < width * height; i++) {
      expect(decoded.sublist(i * 4, i * 4 + 3), rgba.sublist(i * 4, i * 4 + 3));
      expect(decoded[i * 4 + 3], 255);
    }
  });
}
