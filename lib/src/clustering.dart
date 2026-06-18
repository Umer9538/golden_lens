import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import 'image_diff.dart';

/// A connected region of changed pixels, with bounds and centroid in physical
/// pixels.
@immutable
class DiffCluster {
  const DiffCluster({
    required this.bounds,
    required this.changedPixelCount,
    required this.centroid,
  });

  /// Bounding box in physical pixels.
  final Rect bounds;

  /// Number of changed pixels inside [bounds].
  final int changedPixelCount;

  /// Centroid of the changed pixels (physical px) — used for attribution of
  /// sparse / L-shaped clusters whose bbox-center may miss the change.
  final Offset centroid;

  double get area => bounds.width * bounds.height;

  double get density => area == 0 ? 0 : changedPixelCount / area;

  @override
  String toString() =>
      'DiffCluster($bounds, $changedPixelCount px, centroid=$centroid)';
}

/// Groups changed pixels in [mask] into [DiffCluster]s via 8-connectivity
/// flood-fill (optionally on a downsampled grid), dropping noise smaller than
/// `options.minClusterPixels`, merging clusters within `options.mergeGap`, and
/// sorting by magnitude (most-changed first).
List<DiffCluster> clusterMask(
  ChangedMask mask, [
  DiffOptions options = const DiffOptions(),
]) {
  final int ds = options.downsample < 1 ? 1 : options.downsample;
  final int w = (mask.width + ds - 1) ~/ ds;
  final int h = (mask.height + ds - 1) ~/ ds;

  // Downsampled OR-reduction of the mask.
  final Uint8List cell = Uint8List(w * h);
  for (int y = 0; y < mask.height; y++) {
    final int cy = y ~/ ds;
    for (int x = 0; x < mask.width; x++) {
      if (mask.bits[y * mask.width + x] != 0) {
        cell[cy * w + (x ~/ ds)] = 1;
      }
    }
  }

  final Uint8List visited = Uint8List(w * h);
  final List<int> stack = <int>[];
  final List<DiffCluster> clusters = <DiffCluster>[];

  for (int start = 0; start < w * h; start++) {
    if (cell[start] == 0 || visited[start] != 0) continue;
    visited[start] = 1;
    stack.add(start);

    int minX = w, minY = h, maxX = -1, maxY = -1;
    while (stack.isNotEmpty) {
      final int idx = stack.removeLast();
      final int cx = idx % w;
      final int cy = idx ~/ w;
      if (cx < minX) minX = cx;
      if (cx > maxX) maxX = cx;
      if (cy < minY) minY = cy;
      if (cy > maxY) maxY = cy;
      for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final int nx = cx + dx;
          final int ny = cy + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final int nidx = ny * w + nx;
          if (cell[nidx] != 0 && visited[nidx] == 0) {
            visited[nidx] = 1;
            stack.add(nidx);
          }
        }
      }
    }

    // Map the downsampled bbox back to full-resolution physical px.
    final int left = minX * ds;
    final int top = minY * ds;
    final int right = math.min((maxX + 1) * ds, mask.width);
    final int bottom = math.min((maxY + 1) * ds, mask.height);

    // Recompute exact changed-pixel count + centroid at full resolution.
    int count = 0;
    double sumX = 0;
    double sumY = 0;
    for (int y = top; y < bottom; y++) {
      for (int x = left; x < right; x++) {
        if (mask.bits[y * mask.width + x] != 0) {
          count++;
          sumX += x + 0.5;
          sumY += y + 0.5;
        }
      }
    }
    if (count < options.minClusterPixels) continue; // drop noise

    clusters.add(
      DiffCluster(
        bounds: Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        ),
        changedPixelCount: count,
        centroid: Offset(sumX / count, sumY / count),
      ),
    );
  }

  final List<DiffCluster> merged =
      _mergeNearby(clusters, options.mergeGap.toDouble());
  merged.sort((a, b) => b.changedPixelCount.compareTo(a.changedPixelCount));
  return merged;
}

List<DiffCluster> _mergeNearby(List<DiffCluster> input, double gap) {
  final List<DiffCluster> list = List<DiffCluster>.from(input);
  bool changed = true;
  while (changed) {
    changed = false;
    outer:
    for (int i = 0; i < list.length; i++) {
      for (int j = i + 1; j < list.length; j++) {
        if (list[i].bounds.inflate(gap).overlaps(list[j].bounds.inflate(gap))) {
          final DiffCluster a = list[i];
          final DiffCluster b = list[j];
          final int count = a.changedPixelCount + b.changedPixelCount;
          list
            ..removeAt(j)
            ..removeAt(i)
            ..add(
              DiffCluster(
                bounds: a.bounds.expandToInclude(b.bounds),
                changedPixelCount: count,
                centroid: Offset(
                  (a.centroid.dx * a.changedPixelCount +
                          b.centroid.dx * b.changedPixelCount) /
                      count,
                  (a.centroid.dy * a.changedPixelCount +
                          b.centroid.dy * b.changedPixelCount) /
                      count,
                ),
              ),
            );
          changed = true;
          break outer;
        }
      }
    }
  }
  return list;
}
