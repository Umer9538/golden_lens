import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

import 'golden_lens_config.dart' show ParityMetric;

/// Outcome of a golden_lens analysis.
enum GoldenStatus { pass, fail, missingGolden, sizeMismatch, error }

/// The headline parity score.
@immutable
class ParityScore {
  const ParityScore({
    required this.metric,
    required this.score,
    required this.threshold,
  });

  final ParityMetric metric;

  /// Parity in `[0, 1]` (1 = identical).
  final double score;

  /// Advisory threshold in `[0, 1]`.
  final double threshold;

  bool get passed => score >= threshold;

  Map<String, Object?> toJson() => <String, Object?>{
        'metric': metric.name,
        'score': double.parse(score.toStringAsFixed(4)),
        'threshold': threshold,
        'passed': passed,
      };
}

/// One changed region attributed to a widget — the agent's unit of action.
@immutable
class Offender {
  const Offender({
    required this.rank,
    required this.region,
    required this.magnitude,
    required this.changedPixels,
    this.widget,
    this.file,
    this.line,
    this.column,
    this.deltaKind = 'unknown',
    this.deltaHint,
    this.suggestion,
  });

  /// 1-based priority (1 = act first).
  final int rank;

  /// Widget type name, e.g. `Card`.
  final String? widget;

  /// Source file of the owning widget (absolute), or null if unattributed.
  final String? file;
  final int? line;
  final int? column;

  /// Region of change in logical coordinates.
  final Rect region;

  /// Normalized change strength in `[0, 1]`.
  final double magnitude;

  /// Number of changed pixels in the region.
  final int changedPixels;

  /// Coarse change classification (v0.1: usually `unknown`).
  final String deltaKind;

  /// Human-readable delta hint, e.g. `64px changed, region parity 92.0%`.
  final String? deltaHint;

  /// Natural-language suggestion for a human or agent.
  final String? suggestion;

  Map<String, Object?> toJson() => <String, Object?>{
        'rank': rank,
        if (widget != null) 'widget': widget,
        'location': file == null
            ? null
            : <String, Object?>{'file': file, 'line': line, 'column': column},
        'region': <String, Object?>{
          'left': region.left.round(),
          'top': region.top.round(),
          'width': region.width.round(),
          'height': region.height.round(),
        },
        'magnitude': double.parse(magnitude.toStringAsFixed(3)),
        'changedPixels': changedPixels,
        'delta': <String, Object?>{
          'kind': deltaKind,
          if (deltaHint != null) 'hint': deltaHint,
        },
        if (suggestion != null) 'suggestion': suggestion,
      };
}

/// A complete golden_lens report for a single golden.
@immutable
class LensReport {
  const LensReport({
    required this.status,
    required this.goldenName,
    required this.goldenPath,
    required this.parity,
    required this.offenders,
    required this.candidateSize,
    required this.goldenSize,
  });

  final GoldenStatus status;
  final String goldenName;
  final String goldenPath;
  final ParityScore parity;
  final List<Offender> offenders;
  final Size candidateSize;
  final Size goldenSize;

  /// Deterministic JSON (schema v1.0). Timestamps / report paths are added by
  /// the writer, not here, so this stays test-stable.
  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': '1.0',
        'tool': 'golden_lens',
        'status': status.name,
        'golden': <String, Object?>{
          'name': goldenName,
          'path': goldenPath,
          'size': _sizeJson(goldenSize),
        },
        'candidate': <String, Object?>{'size': _sizeJson(candidateSize)},
        'parity': parity.toJson(),
        'offenders': <Object?>[for (final Offender o in offenders) o.toJson()],
      };

  static Map<String, Object?> _sizeJson(Size s) => <String, Object?>{
        'width': s.width.round(),
        'height': s.height.round(),
      };
}
