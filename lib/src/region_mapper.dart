import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import 'attribution_engine.dart';
import 'clustering.dart';
import 'pixel_buffer.dart';
import 'ssim.dart';
import 'widget_location.dart';

/// Converts a physical-pixel [physical] rect into logical/global Flutter
/// coordinates (same top-left origin) by dividing by [devicePixelRatio].
///
/// This is the load-bearing bridge: the image pipeline works in physical px,
/// while [attributeRegion] and [AttributedNode.globalBounds] are logical.
Rect physicalToLogical(Rect physical, double devicePixelRatio) {
  final double s = 1.0 / devicePixelRatio;
  return Rect.fromLTRB(
    physical.left * s,
    physical.top * s,
    physical.right * s,
    physical.bottom * s,
  );
}

/// A diff cluster joined to the widget that owns it and a per-region parity.
@immutable
class AttributedDiff {
  const AttributedDiff({
    required this.physicalBounds,
    required this.logicalBounds,
    required this.changedPixelCount,
    required this.node,
    required this.regionParity,
  });

  final Rect physicalBounds;
  final Rect logicalBounds;
  final int changedPixelCount;

  /// The owning widget node, or null if attribution found no local-project
  /// owner at the cluster centroid.
  final AttributedNode? node;

  /// Per-region SSIM parity (0–100).
  final double regionParity;

  WidgetLocation? get location => node?.bestLocation;

  @override
  String toString() =>
      'AttributedDiff(${changedPixelCount}px, parity=${regionParity.toStringAsFixed(1)}% '
      '-> ${location ?? '(unattributed)'})';
}

/// Attributes each [clusters] entry to the innermost owning widget and scores
/// its per-region parity.
///
/// Clusters are in physical px; this converts to logical via the candidate
/// buffer's device pixel ratio and probes [attributeRegion] at the cluster
/// **centroid** (robust for sparse / L-shaped clusters whose bbox-center could
/// miss the changed mass).
List<AttributedDiff> attributeClusters(
  List<DiffCluster> clusters,
  List<AttributedNode> nodes,
  PixelBuffer candidate,
  PixelBuffer golden, {
  bool preferLocalProject = true,
  int ssimWindow = 7,
}) {
  final double dpr = candidate.devicePixelRatio;
  return <AttributedDiff>[
    for (final DiffCluster c in clusters)
      AttributedDiff(
        physicalBounds: c.bounds,
        logicalBounds: physicalToLogical(c.bounds, dpr),
        changedPixelCount: c.changedPixelCount,
        node: attributeRegion(
          Rect.fromCenter(
            center: Offset(c.centroid.dx / dpr, c.centroid.dy / dpr),
            width: 2,
            height: 2,
          ),
          nodes,
          preferLocalProject: preferLocalProject,
        ),
        regionParity:
            ssimRegion(candidate, golden, c.bounds, window: ssimWindow)
                .parityPercent,
      ),
  ];
}
