import 'package:flutter/foundation.dart';

import 'image_diff.dart' show DiffOptions;

/// Output formats golden_lens can emit on a failing golden.
enum ReportFormat { json, html }

/// Parity metric used for the headline score.
enum ParityMetric { ssim, pixelRatio }

/// Configuration for golden_lens analysis and reporting.
@immutable
class GoldenLensConfig {
  const GoldenLensConfig({
    this.parityThreshold = 0.99,
    this.outputDir = 'golden_lens',
    this.formats = const <ReportFormat>{ReportFormat.json, ReportFormat.html},
    this.localProjectRoots,
    this.parityMetric = ParityMetric.ssim,
    this.maxOffenders = 25,
    this.diffOptions = const DiffOptions(),
    this.preferLocalProject = true,
    this.enabled = true,
  });

  /// Advisory parity threshold (0–1). golden_lens never changes a test's
  /// pass/fail; this only flags `parity.passed` in the report.
  final double parityThreshold;

  /// Directory (relative to the test file) where reports are written.
  final String outputDir;

  /// Which report formats to emit.
  final Set<ReportFormat> formats;

  /// Explicit "local project" roots, overriding the SDK/pub-cache heuristic.
  final List<String>? localProjectRoots;

  /// Metric used for the parity score.
  final ParityMetric parityMetric;

  /// Cap on the number of offenders included in a report.
  final int maxOffenders;

  /// Pixel diff / clustering / SSIM tunables.
  final DiffOptions diffOptions;

  /// Prefer attributing to user-project widgets over framework internals.
  final bool preferLocalProject;

  /// Master switch.
  final bool enabled;
}
