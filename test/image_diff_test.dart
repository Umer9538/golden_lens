import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

import 'support/buffers.dart';

void main() {
  test('identical buffers produce no changes', () {
    final a = solid(8, 8, r: 100, g: 100, b: 100);
    final b = solid(8, 8, r: 100, g: 100, b: 100);
    final d = diffBuffers(a, b);
    expect(d.sizeMismatch, isFalse);
    expect(d.mask.changedCount, 0);
    expect(d.hasChanges, isFalse);
  });

  test('1-LSB change ignored, large change flagged (per-channel default)', () {
    final base = solid(8, 8, r: 100, g: 100, b: 100);

    final tiny = withPixel(base, 3, 3, r: 101, g: 100, b: 100); // +1
    expect(diffBuffers(base, tiny).mask.changedCount, 0);

    final big = withPixel(base, 3, 3, r: 255, g: 100, b: 100); // +155
    final d = diffBuffers(base, big);
    expect(d.mask.changedCount, 1);
    expect(d.mask.changed(3, 3), isTrue);
  });

  test('luma mode ignores equal-luma chroma swap that per-channel catches', () {
    // golden green-ish (0,30,0) vs new red-ish (101,0,0): luma ~equal (~21.4).
    final golden =
        withPixel(solid(8, 8, r: 100, g: 100, b: 100), 2, 2, r: 0, g: 30, b: 0);
    final newer = withPixel(solid(8, 8, r: 100, g: 100, b: 100), 2, 2,
        r: 101, g: 0, b: 0);

    expect(diffBuffers(golden, newer).mask.changed(2, 2), isTrue);
    final lumaDiff =
        diffBuffers(golden, newer, const DiffOptions(useLuma: true));
    expect(lumaDiff.mask.changed(2, 2), isFalse);
  });

  test('size mismatch is graceful: border flagged, no throw', () {
    final newer = solid(3, 3, r: 50, g: 50, b: 50);
    final golden = solid(2, 2, r: 50, g: 50, b: 50);
    final d = diffBuffers(newer, golden);
    expect(d.sizeMismatch, isTrue);
    expect(d.mask.changedCount, 5); // 3x3 minus 2x2 overlap
  });
}
