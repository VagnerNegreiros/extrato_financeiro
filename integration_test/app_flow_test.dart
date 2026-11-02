import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/flows/main_flow.dart';

/// Same journey as `test/flows/main_flow_test.dart`, on a real device or
/// emulator: real rendering, real gestures and the real SQLite build.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main flow on device', runMainFlow);
}
