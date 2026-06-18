import 'package:flutter/foundation.dart';

/// A decoded raster image as raw RGBA bytes, plus the device pixel ratio it was
/// captured at.
///
/// Both captured (rasterized) widgets and decoded golden PNGs are normalized to
/// this representation: row-major, top-left origin, 4 bytes (R, G, B, A) per
/// pixel, straight (non-premultiplied) alpha. [width]/[height] are in **physical
/// pixels** (= logical size × [devicePixelRatio]).
@immutable
class PixelBuffer {
  const PixelBuffer({
    required this.rgba,
    required this.width,
    required this.height,
    required this.devicePixelRatio,
  });

  /// Length is always `width * height * 4`.
  final Uint8List rgba;

  /// Width in physical pixels.
  final int width;

  /// Height in physical pixels.
  final int height;

  /// The device pixel ratio this buffer was captured at — the single source of
  /// truth for converting physical pixels back to logical Flutter coordinates.
  final double devicePixelRatio;

  /// Bytes per row.
  int get rowStride => width * 4;

  int _i(int x, int y) => (y * width + x) * 4;

  int r(int x, int y) => rgba[_i(x, y)];
  int g(int x, int y) => rgba[_i(x, y) + 1];
  int b(int x, int y) => rgba[_i(x, y) + 2];
  int a(int x, int y) => rgba[_i(x, y) + 3];

  /// Rec. 709 luma in `[0, 255]`.
  double luma(int x, int y) {
    final int p = _i(x, y);
    return 0.2126 * rgba[p] + 0.7152 * rgba[p + 1] + 0.0722 * rgba[p + 2];
  }

  bool sameSizeAs(PixelBuffer other) =>
      width == other.width && height == other.height;

  @override
  String toString() => 'PixelBuffer(${width}x$height @ ${devicePixelRatio}x)';
}
