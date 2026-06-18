import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_lens/golden_lens.dart';

void main() {
  testWidgets(
      'attributes a region to the innermost owning widget + source line',
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
    final Rect outerRect = tester.getRect(find.byKey(const Key('outer')));

    final RenderObject root =
        tester.element(find.byType(MaterialApp)).renderObject!;
    final nodes = captureAttributedTree(root);

    expect(nodes, isNotEmpty);
    expect(nodes.where((n) => n.isLocalProject), isNotEmpty,
        reason: 'at least some nodes should resolve to this test file');

    // --- A region of changed pixels INSIDE the inner box ---
    final innerRegion =
        Rect.fromCenter(center: innerRect.center, width: 4, height: 4);
    final innerHit = attributeRegion(innerRegion, nodes);
    debugPrint('inner hit  -> $innerHit');

    expect(innerHit, isNotNull);
    expect(innerHit!.globalBounds.width, closeTo(40, 1));
    expect(innerHit.globalBounds.height, closeTo(40, 1));
    expect(innerHit.resolvedLocation, isNotNull);
    expect(innerHit.resolvedLocation!.file,
        contains('attribution_engine_test.dart'));

    // --- A region INSIDE the outer container but OUTSIDE the inner box ---
    final outerPoint = Offset(outerRect.left + 8, outerRect.center.dy);
    final outerRegion =
        Rect.fromCenter(center: outerPoint, width: 4, height: 4);
    final outerHit = attributeRegion(outerRegion, nodes);
    debugPrint('outer hit  -> $outerHit');

    expect(outerHit, isNotNull);
    expect(outerHit!.globalBounds.width, closeTo(200, 1),
        reason: 'should pick the container region, not the inner box');
    expect(outerHit.globalBounds.height, closeTo(100, 1));
    expect(outerHit.resolvedLocation, isNotNull);
    // A Container is a composite of framework render objects; resolution must
    // walk up to the user's `Container(...)` call site, not Flutter internals.
    expect(outerHit.resolvedLocation!.file,
        contains('attribution_engine_test.dart'));
    expect(isLocalProjectFile(outerHit.resolvedLocation!.file), isTrue);

    // --- The two regions must attribute to DIFFERENT source lines ---
    expect(
      innerHit.resolvedLocation!.line,
      isNot(equals(outerHit.resolvedLocation!.line)),
      reason: 'inner box and container live on different lines',
    );
  });

  test('isLocalProjectFile distinguishes user code from SDK/pub', () {
    expect(isLocalProjectFile('/Users/me/app/lib/card.dart'), isTrue);
    expect(
        isLocalProjectFile(
            '/Users/me/development/flutter/packages/flutter/lib/src/widgets/container.dart'),
        isFalse);
    expect(
        isLocalProjectFile(
            '/Users/me/.pub-cache/hosted/pub.dev/foo/lib/a.dart'),
        isFalse);
    expect(isLocalProjectFile('dart:ui'), isFalse);
    expect(isLocalProjectFile(''), isFalse);
  });
}
