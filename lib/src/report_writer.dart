import 'dart:io';

import 'golden_lens_config.dart';
import 'lens_report.dart';
import 'report_html.dart';
import 'report_json.dart';

/// Writes the configured report formats for [report] into [outputDir].
///
/// Returns the paths written. Uses `dart:io` (test/VM only).
List<String> writeReports(
  LensReport report, {
  required GoldenLensConfig config,
  required Directory outputDir,
  String? goldenPngBase64,
  String? candidatePngBase64,
  String? diffPngBase64,
  String? generatedAt,
}) {
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }
  final String base = _baseName(report.goldenName);
  final List<String> written = <String>[];

  String? htmlRelative;
  if (config.formats.contains(ReportFormat.html)) {
    final File f = File('${outputDir.path}/$base.report.html');
    f.writeAsStringSync(
      encodeReportHtml(
        report,
        goldenPngBase64: goldenPngBase64,
        candidatePngBase64: candidatePngBase64,
        diffPngBase64: diffPngBase64,
      ),
    );
    htmlRelative = '${config.outputDir}/$base.report.html';
    written.add(f.path);
  }

  if (config.formats.contains(ReportFormat.json)) {
    final File f = File('${outputDir.path}/$base.report.json');
    f.writeAsStringSync(
      encodeReportJson(report,
          htmlPath: htmlRelative, generatedAt: generatedAt),
    );
    written.add(f.path);
  }

  return written;
}

String _baseName(String goldenName) {
  final String n = goldenName.split('/').last;
  final int dot = n.lastIndexOf('.');
  return dot > 0 ? n.substring(0, dot) : n;
}
