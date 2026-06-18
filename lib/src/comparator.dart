import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attribution_engine.dart';
import 'golden_lens_config.dart';
import 'image_capture.dart';
import 'lens_engine.dart';
import 'lens_report.dart';
import 'report_writer.dart';

/// Installs golden_lens as the active golden comparator.
///
/// Call from `test/flutter_test_config.dart`:
/// ```dart
/// Future<void> testExecutable(FutureOr<void> Function() main) async {
///   installGoldenLens();
///   await main();
/// }
/// ```
/// After this, every `matchesGoldenFile` (and alchemist) golden gains
/// attribution on failure, with no test changes.
void installGoldenLens({GoldenLensConfig config = const GoldenLensConfig()}) {
  final GoldenFileComparator existing = goldenFileComparator;
  final Uri basedir = existing is LocalFileComparator
      ? existing.basedir
      : Directory.current.uri;
  goldenFileComparator = LensGoldenComparator(
    basedir.resolve('flutter_test_config.dart'),
    config: config,
  );
}

/// A drop-in [GoldenFileComparator] that wraps the standard local comparison
/// and, on failure, writes an attributed report (which widget / source line
/// changed + a parity score + an agent-consumable JSON payload).
///
/// It never changes a test's pass/fail — it only enriches failures.
class LensGoldenComparator extends LocalFileComparator {
  LensGoldenComparator(super.testFile,
      {this.config = const GoldenLensConfig()});

  final GoldenLensConfig config;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    bool passed;
    Object? thrown;
    StackTrace? stack;
    try {
      passed = await super.compare(imageBytes, golden);
    } catch (e, s) {
      // LocalFileComparator throws (with failure artifacts) on mismatch.
      passed = false;
      thrown = e;
      stack = s;
    }

    if (!passed && config.enabled) {
      try {
        await _analyzeAndReport(imageBytes, golden);
      } catch (_) {
        // Reporting must never break or alter the test outcome.
      }
    }

    if (thrown != null) {
      Error.throwWithStackTrace(thrown, stack!);
    }
    return passed;
  }

  Future<void> _analyzeAndReport(Uint8List candidateBytes, Uri golden) async {
    List<int> goldenBytes;
    try {
      goldenBytes = await getGoldenBytes(golden);
    } catch (_) {
      return; // missing golden: super already failed appropriately
    }

    final double dpr = _ambientDevicePixelRatio();
    final candidate = await loadGoldenPng(
      Uint8List.fromList(candidateBytes),
      devicePixelRatio: dpr,
    );
    final goldenBuffer = await loadGoldenPng(
      Uint8List.fromList(goldenBytes),
      devicePixelRatio: dpr,
    );

    final List<AttributedNode> nodes = _captureRootTree();
    final String name = golden.pathSegments.isNotEmpty
        ? golden.pathSegments.last
        : golden.toString();

    final LensReport report = analyzeBuffers(
      candidate: candidate,
      golden: goldenBuffer,
      nodes: nodes,
      goldenName: name,
      goldenPath: golden.toString(),
      config: config,
    );

    writeReports(
      report,
      config: config,
      outputDir: Directory.fromUri(basedir.resolve('${config.outputDir}/')),
      goldenPngBase64: base64Encode(goldenBytes),
      candidatePngBase64: base64Encode(candidateBytes),
    );
  }

  List<AttributedNode> _captureRootTree() {
    final RenderObject? root =
        WidgetsBinding.instance.rootElement?.renderObject;
    if (root == null) return const <AttributedNode>[];
    return captureAttributedTree(root);
  }

  double _ambientDevicePixelRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) return views.first.devicePixelRatio;
    return 3.0;
  }
}
