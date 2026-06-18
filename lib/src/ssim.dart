import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import 'pixel_buffer.dart';

/// Structural-similarity result.
@immutable
class SsimResult {
  const SsimResult({required this.mssim, required this.parityPercent});

  /// Mean SSIM over all windows, in `[-1, 1]` (1 = identical).
  final double mssim;

  /// Convenience: `clamp(mssim, 0, 1) * 100`, a 0–100 "parity %".
  final double parityPercent;

  @override
  String toString() => 'SsimResult(mssim=$mssim, parity=$parityPercent%)';
}

// Wang et al. constants for 8-bit dynamic range (L = 255).
const double _c1 = 6.5025; // (0.01 * 255)^2
const double _c2 = 58.5225; // (0.03 * 255)^2

/// Global SSIM between two equal-size buffers.
SsimResult ssimGlobal(
  PixelBuffer a,
  PixelBuffer b, {
  int window = 7,
  int step = 1,
}) {
  final _SsimTables t = _SsimTables(a, b);
  return t.overRect(Rect.fromLTWH(0, 0, t.w.toDouble(), t.h.toDouble()),
      window: window, step: step);
}

/// SSIM over a physical-pixel [region] (clipped to the image).
SsimResult ssimRegion(
  PixelBuffer a,
  PixelBuffer b,
  Rect region, {
  int window = 7,
  int step = 1,
}) {
  final _SsimTables t = _SsimTables(a, b);
  return t.overRect(region, window: window, step: step);
}

/// Precomputed grayscale + summed-area tables shared across global/region SSIM.
class _SsimTables {
  _SsimTables(PixelBuffer a, PixelBuffer b)
      : assert(a.sameSizeAs(b), 'SSIM requires equal-size buffers'),
        w = a.width,
        h = a.height {
    final int n = w * h;
    final Float64List ga = Float64List(n);
    final Float64List gb = Float64List(n);
    final Float64List gaa = Float64List(n);
    final Float64List gbb = Float64List(n);
    final Float64List gab = Float64List(n);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int i = y * w + x;
        final double va = a.luma(x, y);
        final double vb = b.luma(x, y);
        ga[i] = va;
        gb[i] = vb;
        gaa[i] = va * va;
        gbb[i] = vb * vb;
        gab[i] = va * vb;
      }
    }
    _satA = _buildSat(ga);
    _satB = _buildSat(gb);
    _satAA = _buildSat(gaa);
    _satBB = _buildSat(gbb);
    _satAB = _buildSat(gab);
  }

  final int w;
  final int h;
  late final Float64List _satA;
  late final Float64List _satB;
  late final Float64List _satAA;
  late final Float64List _satBB;
  late final Float64List _satAB;

  Float64List _buildSat(Float64List v) {
    final int stride = w + 1;
    final Float64List sat = Float64List(stride * (h + 1));
    for (int y = 1; y <= h; y++) {
      double rowSum = 0;
      for (int x = 1; x <= w; x++) {
        rowSum += v[(y - 1) * w + (x - 1)];
        sat[y * stride + x] = sat[(y - 1) * stride + x] + rowSum;
      }
    }
    return sat;
  }

  double _sum(Float64List sat, int x0, int y0, int x1, int y1) {
    final int stride = w + 1;
    return sat[y1 * stride + x1] -
        sat[y0 * stride + x1] -
        sat[y1 * stride + x0] +
        sat[y0 * stride + x0];
  }

  double _windowSsim(int x0, int y0, int x1, int y1) {
    final int n = (x1 - x0) * (y1 - y0);
    if (n <= 0) return 1.0;
    final double sumA = _sum(_satA, x0, y0, x1, y1);
    final double sumB = _sum(_satB, x0, y0, x1, y1);
    final double sumAA = _sum(_satAA, x0, y0, x1, y1);
    final double sumBB = _sum(_satBB, x0, y0, x1, y1);
    final double sumAB = _sum(_satAB, x0, y0, x1, y1);

    final double muA = sumA / n;
    final double muB = sumB / n;
    final double varA = sumAA / n - muA * muA;
    final double varB = sumBB / n - muB * muB;
    final double covAB = sumAB / n - muA * muB;

    return ((2 * muA * muB + _c1) * (2 * covAB + _c2)) /
        ((muA * muA + muB * muB + _c1) * (varA + varB + _c2));
  }

  SsimResult overRect(Rect region, {required int window, required int step}) {
    final int rx0 = region.left.floor().clamp(0, w);
    final int ry0 = region.top.floor().clamp(0, h);
    final int rx1 = region.right.ceil().clamp(0, w);
    final int ry1 = region.bottom.ceil().clamp(0, h);
    final int rw = rx1 - rx0;
    final int rh = ry1 - ry0;
    if (rw <= 0 || rh <= 0) {
      return const SsimResult(mssim: 1, parityPercent: 100);
    }

    final int win = window < 1 ? 1 : window;
    final int stp = step < 1 ? 1 : step;

    double sum = 0;
    int count = 0;
    if (rw < win || rh < win) {
      // Region smaller than a window: one window over the whole region.
      sum = _windowSsim(rx0, ry0, rx1, ry1);
      count = 1;
    } else {
      for (int wy = ry0; wy + win <= ry1; wy += stp) {
        for (int wx = rx0; wx + win <= rx1; wx += stp) {
          sum += _windowSsim(wx, wy, wx + win, wy + win);
          count++;
        }
      }
    }

    final double mssim = count == 0 ? 1.0 : sum / count;
    final double clamped = mssim.clamp(-1.0, 1.0);
    return SsimResult(
      mssim: clamped,
      parityPercent: clamped.clamp(0.0, 1.0) * 100,
    );
  }
}
