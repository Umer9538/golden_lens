# Changelog

## 0.1.0

Initial release.

- **Attribution engine** — maps a changed-pixel region to the innermost owning
  widget and resolves framework-internal render objects up to the user's own
  `file:line:column` (via Flutter's public widget-creation tracking).
- **Image pipeline** — anti-alias-tolerant pixel diff, connected-component
  region clustering, and a summed-area-table SSIM perceptual parity score
  (global + per region). Zero dependencies beyond the Flutter SDK.
- **Drop-in comparator** — `installGoldenLens()` wraps the active golden
  comparator so every `matchesGoldenFile` and alchemist golden gains
  attribution on failure, with no test changes. Never alters pass/fail.
- **Reports** — a machine-readable agent JSON payload (schema v1.0) and a
  self-contained human HTML report.
