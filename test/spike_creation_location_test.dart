// KILL-SWITCH SPIKE for widget_attributed_goldens.
//
// The entire package premise is: during a normal `flutter test` run we can map
// a widget in the tree back to the exact source `file:line` where it was
// created. If this fails, the headline feature ("reads line numbers") is
// impossible and we must fall back to widget-name-only attribution.
//
// This spike proves three things end-to-end:
//   1. Widget-creation tracking is ON under `flutter test`.
//   2. We can recover file:line for a widget via the PUBLIC
//      InspectorSerializationDelegate (no private APIs).
//   3. We can do it render-object-first (the engine's real path:
//      changed pixels -> RenderObject -> debugCreator -> Element -> file:line).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Recovers the creation location JSON ({file, line, column, ...}) for an
/// [Element] using only public Flutter APIs.
Map<String, Object?>? creationLocationOf(Element element) {
  final node = element.toDiagnosticsNode();
  final json = node.toJsonMap(
    InspectorSerializationDelegate(
      service: WidgetInspectorService.instance,
      subtreeDepth: 0,
      includeProperties: false,
      // groupName left null -> non-interactive: skips toId(), still emits
      // creationLocation.
    ),
  );
  return json['creationLocation'] as Map<String, Object?>?;
}

void main() {
  test('SPIKE 1: widget creation tracking is enabled under `flutter test`', () {
    final tracked = WidgetInspectorService.instance.isWidgetCreationTracked();
    debugPrint('isWidgetCreationTracked = $tracked');
    expect(
      tracked,
      isTrue,
      reason:
          'creationLocation requires --track-widget-creation (on by default '
          'in `flutter test`). If this is false the attribution premise needs a '
          'fallback or a flag.',
    );
  });

  testWidgets('SPIKE 2: recover file:line for a widget at its call site',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child:
                SpikeProbeWidget(), // <- expect creationLocation to point here
          ),
        ),
      ),
    );

    final element = find.byType(SpikeProbeWidget).evaluate().single;
    final loc = creationLocationOf(element);
    debugPrint('SpikeProbeWidget creationLocation = $loc');

    expect(loc, isNotNull, reason: 'No creationLocation -> attribution FAILS.');
    final file = loc!['file'] as String?;
    final line = loc['line'] as int?;
    final column = loc['column'] as int?;
    debugPrint('  file=$file line=$line column=$column');

    expect(file, isNotNull);
    expect(file, contains('spike_creation_location_test.dart'));
    expect(line, isNotNull);
  });

  testWidgets(
      'SPIKE 3: render-object-first attribution '
      '(RenderObject -> debugCreator -> Element -> file:line)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 12, height: 12), // a real RenderObject
          ),
        ),
      ),
    );

    final RenderObject ro = tester.renderObject(find.byType(SizedBox).first);
    final Object? creator = ro.debugCreator;
    debugPrint('debugCreator runtimeType = ${creator.runtimeType}');
    expect(
      creator,
      isA<DebugCreator>(),
      reason: 'RenderObject.debugCreator must be a DebugCreator in debug/test '
          'mode so we can walk back to the owning Element.',
    );

    final Element element = (creator! as DebugCreator).element;
    final loc = creationLocationOf(element);
    debugPrint('SizedBox creationLocation = $loc');

    expect(loc, isNotNull,
        reason:
            'render-object-first attribution FAILS without creationLocation.');
    debugPrint(
        '  file=${loc!['file']} line=${loc['line']} column=${loc['column']}');
    expect(loc['file'], contains('spike_creation_location_test.dart'));
    expect(loc['line'], isNotNull);
  });
}

/// A trivial widget whose construction site we try to recover.
class SpikeProbeWidget extends StatelessWidget {
  const SpikeProbeWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
