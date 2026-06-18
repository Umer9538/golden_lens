import 'dart:math';
import 'dart:typed_data';

import 'package:golden_lens/golden_lens.dart';

/// A solid-color [PixelBuffer].
PixelBuffer solid(
  int w,
  int h, {
  int r = 0,
  int g = 0,
  int b = 0,
  int a = 255,
  double dpr = 1,
}) {
  final bytes = Uint8List(w * h * 4);
  for (int i = 0; i < w * h; i++) {
    bytes[i * 4] = r;
    bytes[i * 4 + 1] = g;
    bytes[i * 4 + 2] = b;
    bytes[i * 4 + 3] = a;
  }
  return PixelBuffer(rgba: bytes, width: w, height: h, devicePixelRatio: dpr);
}

/// Returns a copy of [src] with a single pixel overwritten.
PixelBuffer withPixel(
  PixelBuffer src,
  int x,
  int y, {
  required int r,
  int g = 0,
  int b = 0,
  int a = 255,
}) {
  final bytes = Uint8List.fromList(src.rgba);
  final i = (y * src.width + x) * 4;
  bytes[i] = r;
  bytes[i + 1] = g;
  bytes[i + 2] = b;
  bytes[i + 3] = a;
  return PixelBuffer(
    rgba: bytes,
    width: src.width,
    height: src.height,
    devicePixelRatio: src.devicePixelRatio,
  );
}

/// Returns a copy of [src] with a filled rectangle `[x0, x1)` × `[y0, y1)`.
PixelBuffer withBlock(
  PixelBuffer src,
  int x0,
  int y0,
  int x1,
  int y1, {
  required int r,
  int g = 0,
  int b = 0,
  int a = 255,
}) {
  final bytes = Uint8List.fromList(src.rgba);
  for (int y = y0; y < y1; y++) {
    for (int x = x0; x < x1; x++) {
      final i = (y * src.width + x) * 4;
      bytes[i] = r;
      bytes[i + 1] = g;
      bytes[i + 2] = b;
      bytes[i + 3] = a;
    }
  }
  return PixelBuffer(
    rgba: bytes,
    width: src.width,
    height: src.height,
    devicePixelRatio: src.devicePixelRatio,
  );
}

/// A deterministic pseudo-random opaque [PixelBuffer].
PixelBuffer randomBuffer(int w, int h, int seed, {double dpr = 1}) {
  final rnd = Random(seed);
  final bytes = Uint8List(w * h * 4);
  for (int i = 0; i < w * h; i++) {
    bytes[i * 4] = rnd.nextInt(256);
    bytes[i * 4 + 1] = rnd.nextInt(256);
    bytes[i * 4 + 2] = rnd.nextInt(256);
    bytes[i * 4 + 3] = 255;
  }
  return PixelBuffer(rgba: bytes, width: w, height: h, devicePixelRatio: dpr);
}

/// Builds a [ChangedMask] from a list of `[x, y]` changed points.
ChangedMask maskFrom(int w, int h, List<List<int>> points) {
  final bits = Uint8List(w * h);
  int count = 0;
  for (final p in points) {
    final idx = p[1] * w + p[0];
    if (bits[idx] == 0) {
      bits[idx] = 1;
      count++;
    }
  }
  return ChangedMask(bits: bits, width: w, height: h, changedCount: count);
}

/// A filled rectangle of `[x, y]` points, `[x0, x1)` × `[y0, y1)`.
List<List<int>> block(int x0, int y0, int x1, int y1) {
  final pts = <List<int>>[];
  for (int y = y0; y < y1; y++) {
    for (int x = x0; x < x1; x++) {
      pts.add(<int>[x, y]);
    }
  }
  return pts;
}
