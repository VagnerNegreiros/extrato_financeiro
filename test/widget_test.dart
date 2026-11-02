import 'package:extrato_financeiro/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  setUpAll(initTestLocale);

  testWidgets('app boots with the offline stack', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await appTestOverrides(),
        child: const FluxoApp(),
      ),
    );
    await settle(tester);

    expect(find.text('Fluxo'), findsWidgets);
  });
}
