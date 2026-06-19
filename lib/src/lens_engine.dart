import 'attribution_engine.dart';
import 'clustering.dart';
import 'golden_lens_config.dart';
import 'image_diff.dart';
import 'lens_report.dart';
import 'pixel_buffer.dart';
import 'region_mapper.dart';
import 'ssim.dart';
import 'widget_location.dart';

/// Runs the full analysis on two equal-or-different sized buffers and an
/// attributed render tree, producing a [LensReport].
///
/// Pure (no IO): diff → cluster → attribute → score → assemble. Reuses the
/// already-tested pipeline ([diffBuffers], [clusterMask], [attributeClusters],
/// [ssimGlobal]).
LensReport analyzeBuffers({
  required PixelBuffer candidate,
  required PixelBuffer golden,
  required List<AttributedNode> nodes,
  required String goldenName,
  required String goldenPath,
  GoldenLensConfig config = const GoldenLensConfig(),
}) {
  final DiffOptions opts = config.diffOptions;
  final DiffResult diff = diffBuffers(candidate, golden, opts);

  if (diff.sizeMismatch) {
    return LensReport(
      status: GoldenStatus.sizeMismatch,
      goldenName: goldenName,
      goldenPath: goldenPath,
      parity: ParityScore(
        metric: config.parityMetric,
        score: 0,
        threshold: config.parityThreshold,
      ),
      offenders: const <Offender>[],
      candidateSize: diff.newerSize,
      goldenSize: diff.goldenSize,
      devicePixelRatio: candidate.devicePixelRatio,
    );
  }

  if (diff.mask.changedCount == 0) {
    return LensReport(
      status: GoldenStatus.pass,
      goldenName: goldenName,
      goldenPath: goldenPath,
      parity: ParityScore(
        metric: config.parityMetric,
        score: 1,
        threshold: config.parityThreshold,
      ),
      offenders: const <Offender>[],
      candidateSize: diff.newerSize,
      goldenSize: diff.goldenSize,
      devicePixelRatio: candidate.devicePixelRatio,
    );
  }

  final List<DiffCluster> clusters = clusterMask(diff.mask, opts);
  final List<AttributedDiff> attributed = attributeClusters(
    clusters,
    nodes,
    candidate,
    golden,
    preferLocalProject: config.preferLocalProject,
    ssimWindow: opts.ssimWindow,
  );
  final SsimResult global =
      ssimGlobal(candidate, golden, window: opts.ssimWindow);

  final List<Offender> offenders = <Offender>[];
  for (int i = 0; i < attributed.length && i < config.maxOffenders; i++) {
    final AttributedDiff d = attributed[i];
    final WidgetLocation? loc = d.location;
    offenders.add(
      Offender(
        rank: i + 1,
        widget: loc?.name ?? d.node?.renderObjectType,
        file: loc?.file,
        line: loc?.line,
        column: loc?.column,
        region: d.logicalBounds,
        magnitude: (1 - d.regionParity / 100).clamp(0.0, 1.0),
        changedPixels: d.changedPixelCount,
        deltaHint: '${d.changedPixelCount}px changed, '
            'region parity ${d.regionParity.toStringAsFixed(1)}%',
        suggestion: _suggest(loc, d.regionParity),
      ),
    );
  }

  return LensReport(
    status: GoldenStatus.fail,
    goldenName: goldenName,
    goldenPath: goldenPath,
    parity: ParityScore(
      metric: config.parityMetric,
      score: global.parityPercent / 100,
      threshold: config.parityThreshold,
    ),
    offenders: offenders,
    candidateSize: diff.newerSize,
    goldenSize: diff.goldenSize,
    devicePixelRatio: candidate.devicePixelRatio,
  );
}

String _suggest(WidgetLocation? loc, double parity) {
  if (loc == null) {
    return 'A region changed but no local widget could be attributed; '
        'inspect the diff image.';
  }
  return '${loc.name ?? 'Widget'} at ${loc.file}:${loc.line} changed '
      '(region parity ${parity.toStringAsFixed(1)}%). Review this widget.';
}
