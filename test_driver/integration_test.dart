import 'package:integration_test/integration_test_driver.dart';

/// Driver untuk menjalankan test di `integration_test/` pada perangkat/emulator
/// via `flutter drive` (lebih andal daripada `flutter test -d` di Windows):
///
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/<nama>_test.dart -d emulator-5554
Future<void> main() => integrationDriver();
