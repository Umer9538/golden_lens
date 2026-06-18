import 'dart:async';

import 'package:golden_lens/golden_lens.dart';

/// Flutter runs this automatically before the test suite. Installing
/// golden_lens here means every golden in this package gains attribution on
/// failure — with no per-test changes.
Future<void> testExecutable(FutureOr<void> Function() main) async {
  installGoldenLens();
  await main();
}
