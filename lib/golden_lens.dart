/// Agent-grade golden tests for Flutter: attribute visual diffs to the exact
/// widget and source line.
///
/// This is the public API surface (still pre-1.0 and evolving).
library;

export 'src/attribution_engine.dart'
    show
        AttributedNode,
        attributeRegion,
        captureAttributedTree,
        firstLocalLocation,
        globalBoundsOf,
        isLocalProjectFile,
        locationForElement;
export 'src/clustering.dart' show DiffCluster, clusterMask;
export 'src/comparator.dart' show LensGoldenComparator, installGoldenLens;
export 'src/golden_lens_config.dart'
    show GoldenLensConfig, ParityMetric, ReportFormat;
export 'src/image_capture.dart' show capturePixelBuffer, loadGoldenPng;
export 'src/image_diff.dart'
    show ChangedMask, DiffOptions, DiffResult, diffBuffers;
export 'src/lens_engine.dart' show analyzeBuffers;
export 'src/lens_report.dart'
    show GoldenStatus, LensReport, Offender, ParityScore;
export 'src/pixel_buffer.dart' show PixelBuffer;
export 'src/region_mapper.dart'
    show AttributedDiff, attributeClusters, physicalToLogical;
export 'src/report_html.dart' show encodeReportHtml;
export 'src/report_json.dart' show encodeReportJson;
export 'src/report_writer.dart' show writeReports;
export 'src/ssim.dart' show SsimResult, ssimGlobal, ssimRegion;
export 'src/widget_location.dart' show WidgetLocation;
