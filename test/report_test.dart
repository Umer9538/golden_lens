import 'dart:convert';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

LensReport _sampleReport() => const LensReport(
      status: GoldenStatus.fail,
      goldenName: 'card.png',
      goldenPath: 'test/goldens/card.png',
      parity:
          ParityScore(metric: ParityMetric.ssim, score: 0.962, threshold: 0.99),
      offenders: <Offender>[
        Offender(
          rank: 1,
          widget: 'Card',
          file: '/app/lib/card.dart',
          line: 42,
          column: 5,
          region: Rect.fromLTWH(10, 20, 30, 40),
          magnitude: 0.18,
          changedPixels: 64,
          deltaHint: '64px changed',
          suggestion: 'Card shadow grew; check elevation at lib/card.dart:42.',
        ),
      ],
      candidateSize: Size(400, 220),
      goldenSize: Size(400, 220),
    );

void main() {
  test('JSON report follows schema v1.0', () {
    final json = encodeReportJson(_sampleReport());
    final map = jsonDecode(json) as Map<String, Object?>;

    expect(map['schemaVersion'], '1.0');
    expect(map['tool'], 'golden_lens');
    expect(map['status'], 'fail');

    final golden = map['golden']! as Map<String, Object?>;
    expect(golden['name'], 'card.png');
    expect((golden['size']! as Map)['width'], 400);

    final parity = map['parity']! as Map<String, Object?>;
    expect(parity['metric'], 'ssim');
    expect(parity['score'], 0.962);
    expect(parity['passed'], false);

    final offenders = map['offenders']! as List<Object?>;
    expect(offenders, hasLength(1));
    final o = offenders.first! as Map<String, Object?>;
    expect(o['rank'], 1);
    expect(o['widget'], 'Card');
    final loc = o['location']! as Map<String, Object?>;
    expect(loc['file'], '/app/lib/card.dart');
    expect(loc['line'], 42);
    expect(loc['column'], 5);
    final region = o['region']! as Map<String, Object?>;
    expect(region['width'], 30);
    expect((o['delta']! as Map)['kind'], 'unknown');
  });

  test('JSON writer can add non-deterministic extras', () {
    final json = encodeReportJson(
      _sampleReport(),
      generatedAt: '2026-06-19T00:00:00Z',
      htmlPath: 'golden_lens/card.report.html',
    );
    final map = jsonDecode(json) as Map<String, Object?>;
    expect(map['generatedAt'], '2026-06-19T00:00:00Z');
    expect(map['reportHtml'], 'golden_lens/card.report.html');
  });

  test('HTML report is self-contained and lists offenders', () {
    final html = encodeReportHtml(_sampleReport());
    expect(html, contains('<!DOCTYPE html>'));
    expect(html, contains('golden_lens report'));
    expect(html, contains('96.2%')); // parity
    expect(html, contains('Card'));
    expect(html, contains('card.dart:42:5'));
    expect(html, isNot(contains('<script'))); // no JS
  });

  test('HTML embeds base64 images when provided', () {
    final html = encodeReportHtml(
      _sampleReport(),
      goldenPngBase64: 'AAAA',
      candidatePngBase64: 'BBBB',
      diffPngBase64: 'CCCC',
    );
    expect(html, contains('data:image/png;base64,AAAA'));
    expect(html, contains('data:image/png;base64,BBBB'));
    expect(html, contains('data:image/png;base64,CCCC'));
  });
}
