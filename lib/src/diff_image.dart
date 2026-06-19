import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_diff.dart';
import 'lens_report.dart';
import 'pixel_buffer.dart';

/// Renders a diff visualization PNG: [candidate] with changed pixels tinted red
/// and each offender's region outlined, ready to embed in a report.
///
/// Offender regions are in logical coordinates; they are scaled by the
/// candidate's device pixel ratio to land on the physical-pixel image.
Future<Uint8List> renderDiffPng(
  PixelBuffer candidate,
  ChangedMask mask,
  List<Offender> offenders,
) async {
  final int w = candidate.width;
  final int h = candidate.height;
  final double dpr = candidate.devicePixelRatio;
  final Uint8List out = Uint8List.fromList(candidate.rgba);

  for (int i = 0; i < w * h; i++) {
    if (mask.bits[i] != 0) {
      out[i * 4] = (out[i * 4] * 0.35 + 255 * 0.65).round();
      out[i * 4 + 1] = (out[i * 4 + 1] * 0.35).round();
      out[i * 4 + 2] = (out[i * 4 + 2] * 0.35).round();
      out[i * 4 + 3] = 255;
    }
  }

  void plot(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final int i = (y * w + x) * 4;
    out[i] = 255;
    out[i + 1] = 235;
    out[i + 2] = 59;
    out[i + 3] = 255;
  }

  for (final Offender o in offenders) {
    final int l = (o.region.left * dpr).round();
    final int t = (o.region.top * dpr).round();
    final int r = (o.region.right * dpr).round();
    final int b = (o.region.bottom * dpr).round();
    for (int d = 0; d < 2; d++) {
      for (int x = l; x < r; x++) {
        plot(x, t + d);
        plot(x, b - 1 - d);
      }
      for (int y = t; y < b; y++) {
        plot(l + d, y);
        plot(r - 1 - d, y);
      }
    }
  }

  final Completer<ui.Image> c = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, c.complete);
  final ui.Image img = await c.future;
  final ByteData? bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}
