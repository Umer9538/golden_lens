import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

import 'support/buffers.dart';

void main() {
  test('two separated blobs -> two clusters', () {
    final mask = maskFrom(16, 4, <List<int>>[
      ...block(0, 0, 4, 4),
      ...block(10, 0, 14, 4),
    ]);
    final clusters =
        clusterMask(mask, const DiffOptions(minClusterPixels: 1, mergeGap: 1));
    expect(clusters.length, 2);
  });

  test('nearby blobs merge into one', () {
    final mask = maskFrom(16, 4, <List<int>>[
      ...block(0, 0, 4, 4),
      ...block(6, 0, 10, 4),
    ]);
    final clusters =
        clusterMask(mask, const DiffOptions(minClusterPixels: 1, mergeGap: 4));
    expect(clusters.length, 1);
    expect(clusters.first.bounds.left, 0);
    expect(clusters.first.bounds.right, 10);
  });

  test('sub-threshold speckle is dropped', () {
    final mask = maskFrom(16, 16, <List<int>>[
      <int>[5, 5],
    ]);
    expect(clusterMask(mask), isEmpty); // default minClusterPixels = 12
  });

  test('diagonal chain stays one cluster (8-connectivity)', () {
    final mask = maskFrom(8, 8, <List<int>>[
      <int>[0, 0],
      <int>[1, 1],
      <int>[2, 2],
      <int>[3, 3],
    ]);
    final clusters =
        clusterMask(mask, const DiffOptions(minClusterPixels: 1, mergeGap: 1));
    expect(clusters.length, 1);
    expect(clusters.first.changedPixelCount, 4);
  });

  test('centroid lies within cluster bounds', () {
    final mask = maskFrom(8, 8, <List<int>>[
      ...block(0, 0, 2, 8), // left column
      ...block(0, 6, 8, 8), // bottom row -> an L
    ]);
    final clusters =
        clusterMask(mask, const DiffOptions(minClusterPixels: 1, mergeGap: 1));
    expect(clusters.length, 1);
    final b = clusters.first.bounds;
    final c = clusters.first.centroid;
    expect(c.dx >= b.left && c.dx <= b.right, isTrue);
    expect(c.dy >= b.top && c.dy <= b.bottom, isTrue);
  });

  test('clusters are sorted by magnitude (largest first)', () {
    final mask = maskFrom(20, 8, <List<int>>[
      ...block(0, 0, 2, 2), // 4 px
      ...block(10, 0, 16, 6), // 36 px
    ]);
    final clusters =
        clusterMask(mask, const DiffOptions(minClusterPixels: 1, mergeGap: 1));
    expect(clusters.length, 2);
    expect(clusters.first.changedPixelCount, 36);
    expect(clusters.last.changedPixelCount, 4);
  });
}
