import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens_example/main.dart';

void main() {
  // Run once with `--update-goldens` to create the baseline. Then change
  // PriceCard (e.g. its elevation or padding) and re-run: the test fails AND
  // golden_lens writes `golden_lens/price_card.report.json` naming the exact
  // widget + source line that changed.
  testWidgets('PriceCard matches its golden', (tester) async {
    tester.view.physicalSize = const Size(300, 240);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: PriceCard()))),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/price_card.png'),
    );
  });
}
