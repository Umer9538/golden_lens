import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'pixel_buffer.dart';

/// Tunable thresholds for the diff, clustering, and scoring stages.
@immutable
class DiffOptions {
  const DiffOptions({
    this.perChannelThreshold = 16,
    this.useLuma = false,
    this.lumaThreshold = 12.0,
    this.alphaThreshold = 16,
    this.minClusterPixels = 12,
    this.mergeGap = 4,
    this.downsample = 1,
    this.ssimWindow = 7,
  });

  /// A pixel counts as changed when the max absolute per-channel delta exceeds
  /// this (0–255). ~16 absorbs anti-alias / sub-pixel jitter.
  final int perChannelThreshold;

  /// Use luma-only comparison instead of per-channel (suppresses chroma-only
  /// anti-alias shimmer; can miss equal-luma hue swaps).
  final bool useLuma;

  /// Luma delta threshold when [useLuma] is true.
  final double lumaThreshold;

  /// Alpha delta threshold when [useLuma] is true.
  final int alphaThreshold;

  /// Clusters with fewer changed pixels than this are dropped as noise.
  final int minClusterPixels;

  /// Clusters whose bounds are within this many physical px are merged.
  final int mergeGap;

  /// Downsample factor for clustering (1 = none). Bridges 1px gaps and speeds
  /// up flood-fill.
  final int downsample;

  /// SSIM sliding-window size.
  final int ssimWindow;
}

/// A boolean per-pixel changed mask (1 byte per pixel: 0 = same, 1 = changed),
/// sized to the *candidate* (newer) image.
@immutable
class ChangedMask {
  const ChangedMask({
    required this.bits,
    required this.width,
    required this.height,
    required this.changedCount,
  });

  final Uint8List bits;
  final int width;
  final int height;
  final int changedCount;

  bool changed(int x, int y) => bits[y * width + x] != 0;
}

/// Result of [diffBuffers]: the changed mask plus size-mismatch metadata.
@immutable
class DiffResult {
  const DiffResult({
    required this.mask,
    required this.sizeMismatch,
    required this.newerSize,
    required this.goldenSize,
  });

  final ChangedMask mask;
  final bool sizeMismatch;
  final Size newerSize;
  final Size goldenSize;

  bool get hasChanges => mask.changedCount > 0;
}

/// Compares [newer] against [golden] and produces a [DiffResult].
///
/// The mask is sized to [newer]. On a size mismatch, the overlapping region is
/// diffed normally and every [newer] pixel outside the overlap is flagged
/// changed (missing golden data is treated as maximally different).
DiffResult diffBuffers(
  PixelBuffer newer,
  PixelBuffer golden, [
  DiffOptions options = const DiffOptions(),
]) {
  final bool mismatch = !newer.sameSizeAs(golden);
  final int overlapW = math.min(newer.width, golden.width);
  final int overlapH = math.min(newer.height, golden.height);

  final Uint8List bits = Uint8List(newer.width * newer.height);
  int changed = 0;

  for (int y = 0; y < overlapH; y++) {
    for (int x = 0; x < overlapW; x++) {
      if (_pixelChanged(newer, golden, x, y, options)) {
        bits[y * newer.width + x] = 1;
        changed++;
      }
    }
  }

  if (mismatch) {
    for (int y = 0; y < newer.height; y++) {
      for (int x = 0; x < newer.width; x++) {
        if ((x >= overlapW || y >= overlapH) &&
            bits[y * newer.width + x] == 0) {
          bits[y * newer.width + x] = 1;
          changed++;
        }
      }
    }
  }

  return DiffResult(
    mask: ChangedMask(
      bits: bits,
      width: newer.width,
      height: newer.height,
      changedCount: changed,
    ),
    sizeMismatch: mismatch,
    newerSize: Size(newer.width.toDouble(), newer.height.toDouble()),
    goldenSize: Size(golden.width.toDouble(), golden.height.toDouble()),
  );
}

bool _pixelChanged(
  PixelBuffer n,
  PixelBuffer g,
  int x,
  int y,
  DiffOptions o,
) {
  if (o.useLuma) {
    final double dl = (n.luma(x, y) - g.luma(x, y)).abs();
    final int da = (n.a(x, y) - g.a(x, y)).abs();
    return dl > o.lumaThreshold || da > o.alphaThreshold;
  }
  final int dr = (n.r(x, y) - g.r(x, y)).abs();
  final int dg = (n.g(x, y) - g.g(x, y)).abs();
  final int db = (n.b(x, y) - g.b(x, y)).abs();
  final int da = (n.a(x, y) - g.a(x, y)).abs();
  final int maxDelta = math.max(math.max(dr, dg), math.max(db, da));
  return maxDelta > o.perChannelThreshold;
}
