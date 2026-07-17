import 'package:integration_test/integration_test_driver.dart';

/// Driver for `flutter drive` visual / integration runs.
///
/// Example:
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/visual_real_screens_test.dart \
///   --dart-define=RUN_VISUAL_E2E=true
/// ```
Future<void> main() => integrationDriver();
