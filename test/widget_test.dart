import 'package:extrato_financeiro/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FluxoApp()));

    expect(find.text('Fluxo'), findsOneWidget);
  });
}
