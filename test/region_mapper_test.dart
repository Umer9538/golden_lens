import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

import 'support/buffers.dart';

void main() {
  test('physicalToLogical divides by device pixel ratio', () {
    expect(
      physicalToLogical(const Rect.fromLTRB(0, 0, 600, 300), 3.0),
      const Rect.fromLTRB(0, 0, 200, 100),
    );
    expect(
      physicalToLogical(const Rect.fromLTRB(120, 360, 240, 480), 3.0),
      const Rect.fromLTRB(40, 120, 80, 160),
    );
  });

  testWidgets(
      'physical-px cluster maps back to the inner widget (coordinate bridge)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Container(
              key: const Key('outer'),
              width: 200,
              height: 100,
              color: const Color(0xFFFF0000),
              alignment: Alignment.center,
              child: const SizedBox(
                key: Key('inner'),
                width: 40,
                height: 40,
              ),
            ),
          ),
        ),
      ),
    );

    final Rect innerRect = tester.getRect(find.byKey(const Key('inner')));
    final RenderObject root =
        tester.element(find.byType(MaterialApp)).renderObject!;
    final nodes = captureAttributedTree(root);

    const double dpr = 3.0;
    // Simulate the image pipeline: a changed-pixel cluster in PHYSICAL px.
    final Rect physicalBounds = Rect.fromLTRB(
      innerRect.left * dpr,
      innerRect.top * dpr,
      innerRect.right * dpr,
      innerRect.bottom * dpr,
    );

    final Rect backToLogical = physicalToLogical(physicalBounds, dpr);
    expect(backToLogical.center.dx, closeTo(innerRect.center.dx, 0.001));
    expect(backToLogical.center.dy, closeTo(innerRect.center.dy, 0.001));

    final hit = attributeRegion(backToLogical, nodes);
    expect(hit, isNotNull);
    expect(hit!.resolvedLocation!.name, 'SizedBox');
    expect(hit.globalBounds.width, closeTo(40, 1));
  });

  test('attributeClusters wires region -> node + per-region parity', () {
    // Synthetic 12x12 buffers (dpr 1) + a node covering them.
    final candidate = solid(12, 12, r: 0, g: 0, b: 0);
    final golden = solid(12, 12, r: 0, g: 0, b: 0);
    final nodes = <AttributedNode>[
      const AttributedNode(
        renderObjectType: 'RenderTest',
        globalBounds: Rect.fromLTWH(0, 0, 12, 12),
        depth: 1,
        rawLocation: WidgetLocation(
            file: '/app/lib/a.dart', line: 10, column: 2, name: 'A'),
        resolvedLocation: WidgetLocation(
            file: '/app/lib/a.dart', line: 10, column: 2, name: 'A'),
      ),
    ];
    final clusters = <DiffCluster>[
      const DiffCluster(
        bounds: Rect.fromLTWH(2, 2, 4, 4),
        changedPixelCount: 16,
        centroid: Offset(4, 4),
      ),
    ];

    final result = attributeClusters(clusters, nodes, candidate, golden);
    expect(result, hasLength(1));
    expect(result.first.location!.line, 10);
    expect(
        result.first.logicalBounds, const Rect.fromLTWH(2, 2, 4, 4)); // dpr 1
    expect(result.first.regionParity, inInclusiveRange(0, 100));
  });
}
