import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

void main() {
  testWidgets('capturePixelBuffer returns physical-size RGBA of the subject',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: 20,
            height: 10,
            color: const Color(0xFF112233),
          ),
        ),
      ),
    );

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // toImage rasterizes on the real event loop -> must run in runAsync.
    late PixelBuffer buf;
    await tester.runAsync(() async {
      buf = await capturePixelBuffer(boundary, pixelRatio: 3.0);
    });

    expect(buf.devicePixelRatio, 3.0);
    expect(buf.width, 20 * 3);
    expect(buf.height, 10 * 3);

    // Center pixel should be the container's color.
    expect(buf.r(30, 15), closeTo(0x11, 2));
    expect(buf.g(30, 15), closeTo(0x22, 2));
    expect(buf.b(30, 15), closeTo(0x33, 2));
  });

  testWidgets('capture -> encode PNG -> loadGoldenPng round-trips with no diff',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: key,
          child: Container(
            width: 16,
            height: 16,
            color: const Color(0xFF3478F6),
          ),
        ),
      ),
    );

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    late DiffResult diff;
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final Uint8List pngBytes =
          (await image.toByteData(format: ui.ImageByteFormat.png))!
              .buffer
              .asUint8List();
      image.dispose();

      final captured = await capturePixelBuffer(boundary, pixelRatio: 3.0);
      final golden = await loadGoldenPng(pngBytes, devicePixelRatio: 3.0);
      diff = diffBuffers(captured, golden);
    });

    expect(diff.sizeMismatch, isFalse);
    expect(diff.mask.changedCount, 0);
  });
}
