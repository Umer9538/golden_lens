import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'pixel_buffer.dart';

/// Rasterizes [boundary] into a [PixelBuffer] (physical-pixel RGBA).
///
/// [pixelRatio] defaults to the ambient device pixel ratio (3.0 under
/// `flutter test`). The captured image is `logicalSize × pixelRatio`.
///
/// NOTE: under `flutter test` the engine rasterization runs on the real event
/// loop, so direct calls must be inside `tester.runAsync(() async { ... })`
/// (the golden comparator already executes in such a zone).
Future<PixelBuffer> capturePixelBuffer(
  RenderRepaintBoundary boundary, {
  double? pixelRatio,
}) async {
  final double dpr = pixelRatio ?? _ambientDevicePixelRatio();
  final ui.Image image = await boundary.toImage(pixelRatio: dpr);
  try {
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      throw StateError('toByteData(rawRgba) returned null');
    }
    return PixelBuffer(
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
      devicePixelRatio: dpr,
    );
  } finally {
    image.dispose();
  }
}

/// Decodes a golden PNG into a [PixelBuffer]. PNGs carry no DPR, so the caller
/// supplies the [devicePixelRatio] the candidate was captured at (they must be
/// the same physical size for a valid diff).
Future<PixelBuffer> loadGoldenPng(
  Uint8List pngBytes, {
  required double devicePixelRatio,
}) async {
  final ui.Codec codec = await ui.instantiateImageCodec(pngBytes);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw StateError('toByteData(rawRgba) returned null');
      }
      return PixelBuffer(
        rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: image.width,
        height: image.height,
        devicePixelRatio: devicePixelRatio,
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

double _ambientDevicePixelRatio() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isNotEmpty) return views.first.devicePixelRatio;
  return 3.0; // flutter_test default
}
