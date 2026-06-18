import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

import 'support/buffers.dart';

void main() {
  test('identical buffers -> mssim 1, parity 100', () {
    final a = solid(16, 16, r: 120, g: 80, b: 200);
    final r = ssimGlobal(a, a);
    expect(r.mssim, closeTo(1.0, 1e-9));
    expect(r.parityPercent, closeTo(100, 1e-6));
  });

  test('all-black vs all-white -> very low parity', () {
    final r = ssimGlobal(
      solid(16, 16, r: 0, g: 0, b: 0),
      solid(16, 16, r: 255, g: 255, b: 255),
    );
    expect(r.parityPercent, lessThan(5));
  });

  test('region over whole image equals global', () {
    final a = randomBuffer(20, 20, 1);
    final b = randomBuffer(20, 20, 2);
    final global = ssimGlobal(a, b);
    final region = ssimRegion(a, b, Rect.fromLTWH(0, 0, 20, 20));
    expect(region.mssim, closeTo(global.mssim, 1e-9));
  });

  test('SAT-based SSIM matches a naive reference', () {
    final a = randomBuffer(18, 18, 7);
    final b = randomBuffer(18, 18, 9);
    final fast = ssimGlobal(a, b, window: 7, step: 1).mssim;
    final naive = _naiveMssim(a, b, 7, 1);
    expect(fast, closeTo(naive, 1e-6));
  });
}

double _naiveMssim(PixelBuffer a, PixelBuffer b, int win, int step) {
  const double c1 = 6.5025;
  const double c2 = 58.5225;
  double sum = 0;
  int count = 0;
  for (int wy = 0; wy + win <= a.height; wy += step) {
    for (int wx = 0; wx + win <= a.width; wx += step) {
      double sa = 0, sb = 0, saa = 0, sbb = 0, sab = 0;
      for (int y = wy; y < wy + win; y++) {
        for (int x = wx; x < wx + win; x++) {
          final double va = a.luma(x, y);
          final double vb = b.luma(x, y);
          sa += va;
          sb += vb;
          saa += va * va;
          sbb += vb * vb;
          sab += va * vb;
        }
      }
      final int n = win * win;
      final double muA = sa / n;
      final double muB = sb / n;
      final double vA = saa / n - muA * muA;
      final double vB = sbb / n - muB * muB;
      final double cov = sab / n - muA * muB;
      sum += ((2 * muA * muB + c1) * (2 * cov + c2)) /
          ((muA * muA + muB * muB + c1) * (vA + vB + c2));
      count++;
    }
  }
  return sum / count;
}
