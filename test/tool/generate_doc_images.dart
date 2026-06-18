// Generates the README / pub.dev screenshots from a REAL run of the pipeline.
//
//   flutter test test/tool/generate_doc_images.dart
//
// Writes doc/golden.png, doc/new.png, doc/diff.png. Not a unit test (no
// `_test.dart` suffix) so it is skipped by the normal suite.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

class _PriceCard extends StatelessWidget {
  const _PriceCard({this.priceColor});
  final Color? priceColor;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Pro',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(r'$12 / mo', style: TextStyle(color: priceColor)),
            ],
          ),
        ),
      );
}

Future<Uint8List> _boundaryPng(RenderRepaintBoundary b, double dpr) async {
  final ui.Image img = await b.toImage(pixelRatio: dpr);
  final Uint8List png = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  img.dispose();
  return png;
}

Future<Uint8List> _rgbaToPng(Uint8List rgba, int w, int h) async {
  final Completer<ui.Image> c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  final ui.Image img = await c.future;
  final Uint8List png = (await img.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  img.dispose();
  return png;
}

void main() {
  testWidgets('generate doc images', (tester) async {
    tester.view.physicalSize = const Size(300, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final GlobalKey rb = GlobalKey();

    Future<(Uint8List, PixelBuffer)> render(Color? priceColor) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: rb,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFFF5F5F7),
              body: Center(child: _PriceCard(priceColor: priceColor)),
            ),
          ),
        ),
      );
      late Uint8List png;
      late PixelBuffer buf;
      await tester.runAsync(() async {
        final b =
            rb.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        png = await _boundaryPng(b, 1.0);
        buf = await loadGoldenPng(png, devicePixelRatio: 1.0);
      });
      return (png, buf);
    }

    final (Uint8List goldenPng, PixelBuffer goldenBuf) = await render(null);
    final (Uint8List candidatePng, PixelBuffer candidateBuf) =
        await render(const Color(0xFFE53935));
    final RenderObject root =
        tester.element(find.byType(MaterialApp)).renderObject!;
    final nodes = captureAttributedTree(root);

    const opts = DiffOptions(minClusterPixels: 1);
    final DiffResult diff = diffBuffers(candidateBuf, goldenBuf, opts);
    final LensReport report = analyzeBuffers(
      candidate: candidateBuf,
      golden: goldenBuf,
      nodes: nodes,
      goldenName: 'price_card.png',
      goldenPath: 'doc/price_card.png',
      config: const GoldenLensConfig(diffOptions: opts),
    );

    // Build the diff visualization: tint changed pixels red, outline offenders.
    final int w = candidateBuf.width;
    final int h = candidateBuf.height;
    final Uint8List out = Uint8List.fromList(candidateBuf.rgba);
    for (int i = 0; i < w * h; i++) {
      if (diff.mask.bits[i] != 0) {
        out[i * 4] = (out[i * 4] * 0.35 + 255 * 0.65).round();
        out[i * 4 + 1] = (out[i * 4 + 1] * 0.35).round();
        out[i * 4 + 2] = (out[i * 4 + 2] * 0.35).round();
        out[i * 4 + 3] = 255;
      }
    }
    void px(int x, int y) {
      if (x < 0 || y < 0 || x >= w || y >= h) return;
      final int i = (y * w + x) * 4;
      out[i] = 255;
      out[i + 1] = 235;
      out[i + 2] = 59;
      out[i + 3] = 255;
    }

    for (final Offender o in report.offenders) {
      final int l = o.region.left.round();
      final int t = o.region.top.round();
      final int r = o.region.right.round();
      final int b = o.region.bottom.round();
      for (int d = 0; d < 2; d++) {
        for (int x = l; x < r; x++) {
          px(x, t + d);
          px(x, b - 1 - d);
        }
        for (int y = t; y < b; y++) {
          px(l + d, y);
          px(r - 1 - d, y);
        }
      }
    }

    late Uint8List diffPng;
    await tester.runAsync(() async {
      diffPng = await _rgbaToPng(out, w, h);
    });

    final Directory dir = Directory('doc');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('doc/golden.png').writeAsBytesSync(goldenPng);
    File('doc/new.png').writeAsBytesSync(candidatePng);
    File('doc/diff.png').writeAsBytesSync(diffPng);

    // ignore: avoid_print
    print('Wrote doc/golden.png, doc/new.png, doc/diff.png '
        '(parity ${(report.parity.score * 100).toStringAsFixed(1)}%, '
        '${report.offenders.length} offenders)');
  });
}
