import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Pure-Dart BlurHash encoder (no third-party dependency).
///
/// Produces the string format used by every BlurHash renderer
/// (flutter_blurhash on the UI side). Images are decoded at a small target
/// size via dart:ui, so the DCT pass stays trivially cheap.
const String blurHash83Chars =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';

/// Encode a BlurHash (4x3 components) from encoded image bytes.
/// Returns null when decoding fails (e.g. unsupported format on web).
Future<String?> encodeBlurHash(Uint8List imageBytes,
    {int targetSize = 64}) async {
  try {
    final codec =
        await ui.instantiateImageCodec(imageBytes, targetWidth: targetSize);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();
    if (data == null) return null;

    final pixels = data.buffer.asUint8List();
    return encodeBlurHashFromPixels(
      pixels,
      image.width,
      image.height,
      nx: 4,
      ny: 3,
    );
  } catch (e) {
    debugPrint('[BlurHash] encode failed: $e');
    return null;
  }
}

/// Encode from raw RGBA pixels (row-major, 4 bytes per pixel).
String encodeBlurHashFromPixels(Uint8List pixels, int width, int height,
    {int nx = 4, int ny = 3}) {
  final linear = Float64List(width * height * 3);
  for (var p = 0; p < width * height; p++) {
    linear[p * 3] = _srgbToLinear(pixels[p * 4] / 255);
    linear[p * 3 + 1] = _srgbToLinear(pixels[p * 4 + 1] / 255);
    linear[p * 3 + 2] = _srgbToLinear(pixels[p * 4 + 2] / 255);
  }

  // DCT factors: factor[j][i] = (r, g, b)
  final factors =
      List.generate(ny, (_) => List.generate(nx, (_) => Float64List(3)));
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final normalisation = (i == 0 && j == 0) ? 1.0 : 2.0;
      double r = 0, g = 0, b = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final basis = _cosTable(x, width, i) * _cosTable(y, height, j);
          final p = (y * width + x) * 3;
          r += basis * linear[p];
          g += basis * linear[p + 1];
          b += basis * linear[p + 2];
        }
      }
      final scale = normalisation / (width * height);
      factors[j][i][0] = r * scale;
      factors[j][i][1] = g * scale;
      factors[j][i][2] = b * scale;
    }
  }

  final buffer = StringBuffer();
  final dc = factors[0][0];

  // Size flag: (nx - 1) + (ny - 1) * 9
  _write83(buffer, (nx - 1) + (ny - 1) * 9, 1);
  // DC
  _write83(buffer, _encodeDc(dc), 4);

  // AC components, row-major, skipping (0,0)
  var actualMax = 0.0;
  final acValues = <Float64List>[];
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      if (i == 0 && j == 0) continue;
      acValues.add(factors[j][i]);
      for (final v in factors[j][i]) {
        actualMax = math.max(actualMax, v.abs());
      }
    }
  }

  final quantMax = actualMax > 0 ? _quantise(actualMax) : 1;
  _write83(buffer, quantMax, 1);

  for (final ac in acValues) {
    _write83(buffer, _encodeAc(ac, quantMax), 2);
  }

  return buffer.toString();
}

double _cosTable(int pixel, int size, int component) =>
    math.cos(math.pi * component * pixel / size);

double _srgbToLinear(double v) {
  v = v.clamp(0.0, 1.0);
  return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _linearToSrgb(double v) {
  v = v.clamp(0.0, 1.0);
  final s = v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  return (s * 255 + 0.5).floorToDouble();
}

int _encodeDc(Float64List v) =>
    (_linearToSrgb(v[0]).toInt() << 16) +
    (_linearToSrgb(v[1]).toInt() << 8) +
    _linearToSrgb(v[2]).toInt();

int _encodeAc(Float64List v, int quantMax) {
  int q(double channel) {
    final quantised = (_signPow(channel / _dequantise(quantMax), 0.5) * 9 + 9.5)
        .floor();
    return quantised.clamp(0, 18);
  }

  return q(v[0]) * 19 * 19 + q(v[1]) * 19 + q(v[2]);
}

double _signPow(double v, double exp) =>
    v < 0 ? -math.pow(-v, exp).toDouble() : math.pow(v, exp).toDouble();

int _quantise(double v) =>
    math.max(1, (_signPow(v, 0.5) * 9 + 9.5).floor());

double _dequantise(int q) => _signPow((q - 9) / 9, 2.0);

void _write83(StringBuffer buffer, int value, int length) {
  for (var i = 1; i <= length; i++) {
    final digit = (value ~/ math.pow(83, length - i)) % 83;
    buffer.write(blurHash83Chars[digit]);
  }
}
