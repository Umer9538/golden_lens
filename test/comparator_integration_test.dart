import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

Future<Uint8List> _png(RenderRepaintBoundary boundary, double dpr) async {
  final ui.Image image = await boundary.toImage(pixelRatio: dpr);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

Widget _app(GlobalKey rb, Color color) => RepaintBoundary(
      key: rb,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: Center(
            child: Container(
              key: const Key('box'),
              width: 60,
              height: 60,
              color: color,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('comparator writes an attributed report on golden mismatch',
      (tester) async {
    tester.view.physicalSize = const Size(120, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('golden_lens');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final rb = GlobalKey();

    // 1) Render RED, save as the golden on disk.
    await tester.pumpWidget(_app(rb, const Color(0xFFFF0000)));
    late Uint8List goldenPng;
    await tester.runAsync(() async {
      goldenPng = await _png(
          rb.currentContext!.findRenderObject()! as RenderRepaintBoundary, 1.0);
    });
    File('${tmp.path}/box.png').writeAsBytesSync(goldenPng);

    // 2) Render GREEN — the changed candidate.
    await tester.pumpWidget(_app(rb, const Color(0xFF00FF00)));
    late Uint8List candidatePng;
    await tester.runAsync(() async {
      candidatePng = await _png(
          rb.currentContext!.findRenderObject()! as RenderRepaintBoundary, 1.0);
    });

    // 3) Compare via our comparator (basedir = tmp).
    final comparator = LensGoldenComparator(
      Uri.file('${tmp.path}/comparator_integration_test.dart'),
      config: const GoldenLensConfig(
        diffOptions: DiffOptions(minClusterPixels: 1),
      ),
    );

    Object? caught;
    await tester.runAsync(() async {
      try {
        await comparator.compare(candidatePng, Uri.parse('box.png'));
      } catch (e) {
        caught = e;
      }
    });
    expect(caught, isNotNull, reason: 'a mismatch must still fail the golden');

    // 4) The agent report exists and names the Container line.
    final reportFile = File('${tmp.path}/golden_lens/box.report.json');
    expect(reportFile.existsSync(), isTrue);
    final map =
        jsonDecode(reportFile.readAsStringSync()) as Map<String, Object?>;
    expect(map['status'], 'fail');
    expect(map['schemaVersion'], '1.0');

    final offenders = map['offenders']! as List<Object?>;
    expect(offenders, isNotEmpty);
    final first = offenders.first! as Map<String, Object?>;
    expect(first['widget'], 'Container');
    final loc = first['location']! as Map<String, Object?>;
    expect(
        loc['file']! as String, contains('comparator_integration_test.dart'));

    // The human report is also written, with golden + new + diff panels.
    final htmlFile = File('${tmp.path}/golden_lens/box.report.html');
    expect(htmlFile.existsSync(), isTrue);
    final html = htmlFile.readAsStringSync();
    expect('data:image/png;base64,'.allMatches(html).length, 3,
        reason: 'golden, new, and diff images should all be embedded');
    expect(html, contains('>Diff<'));
  });

  testWidgets('comparator writes no report when goldens match', (tester) async {
    tester.view.physicalSize = const Size(120, 120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final tmp = Directory.systemTemp.createTempSync('golden_lens');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final rb = GlobalKey();

    await tester.pumpWidget(_app(rb, const Color(0xFF0000FF)));
    late Uint8List png;
    await tester.runAsync(() async {
      png = await _png(
          rb.currentContext!.findRenderObject()! as RenderRepaintBoundary, 1.0);
    });
    File('${tmp.path}/box.png').writeAsBytesSync(png);

    final comparator = LensGoldenComparator(Uri.file('${tmp.path}/test.dart'));

    late bool passed;
    await tester.runAsync(() async {
      passed = await comparator.compare(png, Uri.parse('box.png'));
    });

    expect(passed, isTrue);
    expect(Directory('${tmp.path}/golden_lens').existsSync(), isFalse);
  });

  test('installGoldenLens swaps in a LensGoldenComparator', () {
    final previous = goldenFileComparator;
    addTearDown(() => goldenFileComparator = previous);
    installGoldenLens();
    expect(goldenFileComparator, isA<LensGoldenComparator>());
  });
}
