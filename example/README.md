# golden_lens example

A minimal app + golden test showing the **zero-config** golden_lens setup.

- `lib/main.dart` — a `PriceCard` widget.
- `test/flutter_test_config.dart` — calls `installGoldenLens()` once for the whole suite.
- `test/price_card_golden_test.dart` — a plain `matchesGoldenFile` test.

Try it:

```bash
flutter pub get
flutter test --update-goldens          # create the baseline
# now edit PriceCard (e.g. elevation: 4 -> 8) and:
flutter test                           # fails, and writes:
#   golden_lens/price_card.report.json  (agent payload)
#   golden_lens/price_card.report.html  (human report)
```

The JSON report names the exact widget and `file:line` that changed.
