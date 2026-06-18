import 'package:flutter/foundation.dart';

/// A source location where a widget was constructed, recovered from Flutter's
/// widget-creation tracking (the `--track-widget-creation` data that powers the
/// DevTools inspector).
///
/// Example: `Card @ lib/card.dart:42:12`.
@immutable
class WidgetLocation {
  const WidgetLocation({
    required this.file,
    required this.line,
    required this.column,
    this.name,
  });

  /// Filesystem path (the `file://` scheme is stripped), e.g.
  /// `/Users/me/app/lib/card.dart`.
  final String file;

  /// 1-based line where the widget was constructed.
  final int line;

  /// 1-based column where the widget was constructed.
  final int column;

  /// The widget's type name, e.g. `Card`. May be null.
  final String? name;

  /// Builds a [WidgetLocation] from the `creationLocation` map produced by
  /// [InspectorSerializationDelegate].
  factory WidgetLocation.fromInspectorJson(Map<String, Object?> json) {
    return WidgetLocation(
      file: _stripScheme(json['file'] as String? ?? ''),
      line: (json['line'] as num?)?.toInt() ?? 0,
      column: (json['column'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
    );
  }

  /// Compact `path:line:column` form, e.g. `lib/card.dart:42:12`.
  String get short => '$file:$line:$column';

  Map<String, Object?> toJson() => <String, Object?>{
        'file': file,
        'line': line,
        'column': column,
        if (name != null) 'name': name,
      };

  static String _stripScheme(String f) =>
      f.startsWith('file://') ? Uri.parse(f).toFilePath() : f;

  @override
  String toString() => '${name ?? '?'} @ $short';

  @override
  bool operator ==(Object other) =>
      other is WidgetLocation &&
      other.file == file &&
      other.line == line &&
      other.column == column &&
      other.name == name;

  @override
  int get hashCode => Object.hash(file, line, column, name);
}
