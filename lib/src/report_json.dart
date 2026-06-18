import 'dart:convert';

import 'lens_report.dart';

/// Encodes [report] as the golden_lens agent JSON payload (schema v1.0).
///
/// [generatedAt] and [htmlPath] are optional non-deterministic extras added by
/// callers/writers; the core [LensReport.toJson] stays stable for testing.
String encodeReportJson(
  LensReport report, {
  String? generatedAt,
  String? htmlPath,
  bool pretty = true,
}) {
  final Map<String, Object?> map = report.toJson();
  if (htmlPath != null) map['reportHtml'] = htmlPath;
  if (generatedAt != null) map['generatedAt'] = generatedAt;
  return pretty
      ? const JsonEncoder.withIndent('  ').convert(map)
      : jsonEncode(map);
}
