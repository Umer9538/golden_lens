import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

import 'support/buffers.dart';

void main() {
  test('identical buffers -> pass, parity 1.0, no offenders', () {
    final a = solid(20, 20, r: 255, g: 255, b: 255);
    final report = analyzeBuffers(
      candidate: a,
      golden: a,
      nodes: const <AttributedNode>[],
      goldenName: 'x.png',
      goldenPath: 'test/x.png',
    );
    expect(report.status, GoldenStatus.pass);
    expect(report.parity.score, closeTo(1.0, 1e-9));
    expect(report.parity.passed, isTrue);
    expect(report.offenders, isEmpty);
  });

  test('diff -> fail, offender attributed to the owning widget line', () {
    final golden = solid(20, 20, r: 255, g: 255, b: 255);
    final candidate = withBlock(golden, 6, 6, 14, 14, r: 0, g: 0, b: 0);

    const nodes = <AttributedNode>[
      AttributedNode(
        renderObjectType: 'RenderBox',
        globalBounds: Rect.fromLTWH(0, 0, 20, 20),
        depth: 1,
        rawLocation: WidgetLocation(
            file: '/app/lib/card.dart', line: 42, column: 5, name: 'Card'),
        resolvedLocation: WidgetLocation(
            file: '/app/lib/card.dart', line: 42, column: 5, name: 'Card'),
      ),
    ];

    final report = analyzeBuffers(
      candidate: candidate,
      golden: golden,
      nodes: nodes,
      goldenName: 'card.png',
      goldenPath: 'test/card.png',
      config: const GoldenLensConfig(
        diffOptions: DiffOptions(minClusterPixels: 1),
      ),
    );

    expect(report.status, GoldenStatus.fail);
    expect(report.parity.score, lessThan(1.0));
    expect(report.offenders, isNotEmpty);

    final first = report.offenders.first;
    expect(first.rank, 1);
    expect(first.widget, 'Card');
    expect(first.file, '/app/lib/card.dart');
    expect(first.line, 42);
    expect(first.changedPixels, 64); // 8x8 block
    expect(first.magnitude, greaterThan(0));
  });

  test('size mismatch -> sizeMismatch status, no crash', () {
    final report = analyzeBuffers(
      candidate: solid(8, 8, r: 10, g: 10, b: 10),
      golden: solid(4, 4, r: 10, g: 10, b: 10),
      nodes: const <AttributedNode>[],
      goldenName: 'm.png',
      goldenPath: 'test/m.png',
    );
    expect(report.status, GoldenStatus.sizeMismatch);
    expect(report.offenders, isEmpty);
  });
}
