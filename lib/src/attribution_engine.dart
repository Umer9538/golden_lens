import 'package:flutter/widgets.dart';

import 'widget_location.dart';

/// A render object in the captured tree, annotated with its global paint bounds
/// and the source location(s) of the widget that owns it.
@immutable
class AttributedNode {
  const AttributedNode({
    required this.renderObjectType,
    required this.globalBounds,
    required this.depth,
    required this.rawLocation,
    required this.resolvedLocation,
  });

  /// The render object's runtime type, e.g. `RenderConstrainedBox`.
  final String renderObjectType;

  /// Paint bounds mapped into the root (global/screen) coordinate space.
  final Rect globalBounds;

  /// Depth in the render tree (root = 0). Deeper = more specific.
  final int depth;

  /// The creation site of the widget that *directly* owns this render object —
  /// which may live inside the framework (e.g. a `ColoredBox` created inside
  /// `Container.build`).
  final WidgetLocation? rawLocation;

  /// The creation site of the nearest ancestor widget that lives in the user's
  /// project (e.g. the `Container(...)` the developer actually wrote). This is
  /// the location a human or an agent cares about. Null if none is local.
  final WidgetLocation? resolvedLocation;

  /// Whether a local-project owner was found.
  bool get isLocalProject => resolvedLocation != null;

  /// Area of the global bounds; smaller = tighter fit = more specific.
  double get area => globalBounds.width * globalBounds.height;

  /// The best location to report: the local-project owner if known, else the
  /// raw owner.
  WidgetLocation? get bestLocation => resolvedLocation ?? rawLocation;

  @override
  String toString() =>
      '$renderObjectType ${_fmtRect(globalBounds)} -> ${bestLocation ?? '(no location)'}';
}

/// Recovers the `creationLocation` for a single [element] using only public
/// Flutter APIs ([InspectorSerializationDelegate]). Returns null if widget
/// creation tracking is off or the element has no location.
WidgetLocation? locationForElement(Element element) {
  if (!WidgetInspectorService.instance.isWidgetCreationTracked()) return null;
  final Map<String, Object?> json = element.toDiagnosticsNode().toJsonMap(
        InspectorSerializationDelegate(
          service: WidgetInspectorService.instance,
          subtreeDepth: 0,
          includeProperties: false,
        ),
      );
  final Object? loc = json['creationLocation'];
  if (loc is! Map) return null;
  return WidgetLocation.fromInspectorJson(loc.cast<String, Object?>());
}

/// Walks [element] and its ancestors and returns the first creation location
/// that lives in the user's project. This maps framework-internal render
/// objects back to the widget the developer actually wrote.
WidgetLocation? firstLocalLocation(Element element) {
  for (final Element el in element.debugGetDiagnosticChain()) {
    final WidgetLocation? loc = locationForElement(el);
    if (loc != null && isLocalProjectFile(loc.file)) return loc;
  }
  return null;
}

/// Heuristic: a file is "local project" if it is not part of the Dart/Flutter
/// SDK or a pub package cache. Good enough for v0.1; later versions can use the
/// inspector's `pubRootDirectories` for an exact answer.
bool isLocalProjectFile(String file) {
  if (file.isEmpty || file.startsWith('dart:')) return false;
  final String lower = file.toLowerCase();
  if (lower.contains('/.pub-cache/')) return false;
  if (lower.contains('/pub.dartlang.org/')) return false;
  if (lower.contains('/hosted/pub.dev/')) return false;
  if (lower.contains('/flutter/packages/flutter')) return false;
  if (lower.contains('/flutter/bin/cache/')) return false;
  return true;
}

/// Captures every render object under [root] as an [AttributedNode], in
/// depth-first paint order, annotated with global bounds and source location.
List<AttributedNode> captureAttributedTree(RenderObject root) {
  final List<AttributedNode> nodes = <AttributedNode>[];

  void visit(RenderObject ro, int depth) {
    final Rect? bounds = globalBoundsOf(ro);
    if (bounds != null) {
      WidgetLocation? raw;
      WidgetLocation? resolved;
      final Object? creator = ro.debugCreator;
      if (creator is DebugCreator) {
        final Element element = creator.element;
        raw = locationForElement(element);
        resolved = firstLocalLocation(element);
      }
      nodes.add(
        AttributedNode(
          renderObjectType: ro.runtimeType.toString(),
          globalBounds: bounds,
          depth: depth,
          rawLocation: raw,
          resolvedLocation: resolved,
        ),
      );
    }
    ro.visitChildren((RenderObject child) => visit(child, depth + 1));
  }

  visit(root, 0);
  return nodes;
}

/// Maps [ro]'s local paint bounds into the root coordinate space. Returns null
/// if the render object is detached or not yet laid out.
Rect? globalBoundsOf(RenderObject ro) {
  if (!ro.attached) return null;
  try {
    final Matrix4 transform = ro.getTransformTo(null);
    return MatrixUtils.transformRect(transform, ro.paintBounds);
  } catch (_) {
    return null;
  }
}

/// Hit-tests a changed-pixel [region] against captured [nodes] and returns the
/// innermost owning node.
///
/// Strategy (v0.1): among nodes whose bounds contain the region's centre, prefer
/// nodes that fully contain the region, then pick the smallest area (tightest
/// fit), breaking ties by greatest depth. When [preferLocalProject] is true,
/// nodes resolvable to user code win over framework-only nodes.
AttributedNode? attributeRegion(
  Rect region,
  List<AttributedNode> nodes, {
  bool preferLocalProject = true,
}) {
  final Offset center = region.center;

  List<AttributedNode> candidates = nodes
      .where((AttributedNode n) =>
          n.globalBounds.contains(center) &&
          (preferLocalProject ? n.isLocalProject : n.bestLocation != null))
      .toList();

  if (candidates.isEmpty) return null;

  final List<AttributedNode> fullyContaining = candidates
      .where((AttributedNode n) => _containsRect(n.globalBounds, region))
      .toList();
  final List<AttributedNode> pool =
      fullyContaining.isNotEmpty ? fullyContaining : candidates;

  pool.sort((AttributedNode a, AttributedNode b) {
    final int byArea = a.area.compareTo(b.area);
    if (byArea != 0) return byArea;
    return b.depth.compareTo(a.depth);
  });

  return pool.first;
}

bool _containsRect(Rect outer, Rect inner) =>
    outer.left <= inner.left &&
    outer.top <= inner.top &&
    outer.right >= inner.right &&
    outer.bottom >= inner.bottom;

String _fmtRect(Rect r) =>
    '(${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)} '
    '${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)})';
