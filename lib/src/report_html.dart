import 'lens_report.dart';

const String _css = '''
:root { color-scheme: light dark; }
body { font-family: -apple-system, system-ui, sans-serif; margin: 24px; line-height: 1.4; }
h1 { font-size: 20px; margin: 0 0 4px; }
.meta { color: #888; margin: 0 0 16px; }
.badge { font-weight: 700; }
.images { display: flex; gap: 16px; flex-wrap: wrap; margin: 16px 0; }
.images figure { margin: 0; }
.images img { max-width: 320px; border: 1px solid #ccc; image-rendering: pixelated; }
.images figcaption { font-size: 12px; color: #888; text-align: center; }
ol.offenders { padding-left: 20px; }
ol.offenders li { margin: 6px 0; }
code { background: rgba(127,127,127,0.18); padding: 1px 5px; border-radius: 4px; }
.suggestion { color: #888; font-size: 13px; }
''';

/// Renders a self-contained HTML report (no JS, no external assets).
///
/// Pass base64-encoded PNGs to embed the golden / candidate / diff images.
String encodeReportHtml(
  LensReport report, {
  String? goldenPngBase64,
  String? candidatePngBase64,
  String? diffPngBase64,
}) {
  final StringBuffer b = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en"><head><meta charset="utf-8">')
    ..writeln('<title>golden_lens — ${_esc(report.goldenName)}</title>')
    ..writeln('<style>$_css</style></head><body>')
    ..writeln('<h1>golden_lens report</h1>')
    ..writeln('<p class="meta">${_esc(report.goldenName)} — status '
        '<span class="badge">${report.status.name}</span> — parity '
        '<span class="badge">'
        '${(report.parity.score * 100).toStringAsFixed(1)}%</span></p>');

  if (goldenPngBase64 != null ||
      candidatePngBase64 != null ||
      diffPngBase64 != null) {
    b.writeln('<div class="images">');
    _figure(b, 'Golden', goldenPngBase64);
    _figure(b, 'New', candidatePngBase64);
    _figure(b, 'Diff', diffPngBase64);
    b.writeln('</div>');
  }

  if (report.offenders.isEmpty) {
    b.writeln('<p>No attributed offenders.</p>');
  } else {
    b.writeln('<ol class="offenders">');
    for (final Offender o in report.offenders) {
      final String loc = o.file == null
          ? '(unattributed)'
          : '${_esc(o.file!)}:${o.line}:${o.column}';
      b
        ..writeln('<li><b>${_esc(o.widget ?? '?')}</b> — <code>$loc</code> — '
            '${(o.magnitude * 100).toStringAsFixed(0)}% changed')
        ..writeln(o.suggestion == null
            ? ''
            : '<div class="suggestion">${_esc(o.suggestion!)}</div>')
        ..writeln('</li>');
    }
    b.writeln('</ol>');
  }

  b.writeln('</body></html>');
  return b.toString();
}

void _figure(StringBuffer b, String caption, String? base64Png) {
  if (base64Png == null) return;
  b.writeln('<figure><img alt="$caption" '
      'src="data:image/png;base64,$base64Png">'
      '<figcaption>$caption</figcaption></figure>');
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
