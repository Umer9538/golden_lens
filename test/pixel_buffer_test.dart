import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

void main() {
  test('pixel accessors and Rec.709 luma', () {
    // 2x2: (0,0)=white, (1,0)=black, (0,1)=red, (1,1)=green
    final rgba = Uint8List.fromList(<int>[
      255, 255, 255, 255, 0, 0, 0, 255, //
      255, 0, 0, 255, 0, 255, 0, 255, //
    ]);
    final p =
        PixelBuffer(rgba: rgba, width: 2, height: 2, devicePixelRatio: 3.0);

    expect(p.rowStride, 8);
    expect(p.devicePixelRatio, 3.0);

    expect(p.r(0, 0), 255);
    expect(p.a(1, 0), 255);
    expect(p.r(0, 1), 255);
    expect(p.g(0, 1), 0);
    expect(p.g(1, 1), 255);

    expect(p.luma(0, 0), closeTo(255, 0.001)); // white
    expect(p.luma(1, 0), closeTo(0, 0.001)); // black
    expect(p.luma(0, 1), closeTo(54.213, 0.01)); // red
    expect(p.luma(1, 1), closeTo(182.376, 0.01)); // green
  });
}
