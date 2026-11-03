import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Encodes [rgba] pixels (4 bytes each, row by row) of a [width]×[height]
/// image as a PNG without an alpha channel: 8-bit truecolor, the alpha byte
/// dropped.
///
/// App Store Connect rejects screenshots that carry an alpha channel, and
/// `dart:ui` only encodes RGBA PNGs.
@internal
Uint8List encodeOpaquePng(Uint8List rgba, int width, int height) {
  assert(rgba.length == width * height * 4);
  // Each row starts with filter type 0 (none).
  final rowBytes = width * 3 + 1;
  final raw = Uint8List(rowBytes * height);
  for (var y = 0; y < height; y++) {
    var out = y * rowBytes + 1;
    var inp = y * width * 4;
    for (var x = 0; x < width; x++, inp += 4) {
      raw[out++] = rgba[inp];
      raw[out++] = rgba[inp + 1];
      raw[out++] = rgba[inp + 2];
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // color type: truecolor
    ..setUint8(10, 0) // compression
    ..setUint8(11, 0) // filter
    ..setUint8(12, 0); // interlace
  final png = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _chunk(png, 'IHDR', header.buffer.asUint8List());
  _chunk(png, 'IDAT', Uint8List.fromList(ZLibEncoder().convert(raw)));
  _chunk(png, 'IEND', Uint8List(0));
  return png.takeBytes();
}

void _chunk(BytesBuilder png, String type, Uint8List data) {
  final typeBytes = Uint8List.fromList(type.codeUnits);
  png
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  var crc = _crc(0xFFFFFFFF, typeBytes);
  crc = _crc(crc, data) ^ 0xFFFFFFFF;
  png.add((ByteData(4)..setUint32(0, crc)).buffer.asUint8List());
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc(int crc, Uint8List bytes) {
  var c = crc;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >>> 8);
  }
  return c;
}
