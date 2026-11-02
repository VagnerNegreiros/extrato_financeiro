import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/repositories/market_quote_repository_impl.dart';
import 'package:extrato_financeiro/features/preferences/data/preferences_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fake_market.dart';

void main() {
  group('MarketQuoteRepositoryImpl', () {
    late FixedClock clock;
    late CountingMarket market;
    late MarketQuoteRepositoryImpl repository;

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 11, 2, 15));
      market = CountingMarket(instantFakeMarket(clock));
      repository = MarketQuoteRepositoryImpl(remote: market, clock: clock);
    });

    test('converts the price to cents and caches it for 60 seconds', () async {
      final first = (await repository.getCurrentQuote('bitcoin')).valueOrNull!;
      expect(first.price.isPositive, isTrue);
      expect(first.fetchedAt, clock.nowUtc());

      clock.advance(const Duration(seconds: 59));
      expect((await repository.getCurrentQuote('bitcoin')).valueOrNull, first);
      expect(market.priceCalls, 1);

      clock.advance(const Duration(seconds: 1));
      await repository.getCurrentQuote('bitcoin');
      expect(market.priceCalls, 2);
    });

    test('maps errors to failures and does not cache them', () async {
      market.errorToThrow = const NetworkException();
      expect(
        (await repository.getCurrentQuote('bitcoin')).failureOrNull,
        isA<NetworkFailure>(),
      );

      market.errorToThrow = null;
      expect((await repository.getCurrentQuote('bitcoin')).isSuccess, isTrue);
    });

    test('forwards the cancellation', () async {
      final result = await repository.getCurrentQuote(
        'bitcoin',
        cancellation: Cancellation()..cancel(),
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });

  group('RN-29: PreferencesRepositoryImpl', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('balance is visible by default and the choice persists', () async {
      final repository = PreferencesRepositoryImpl(
        await SharedPreferences.getInstance(),
      );
      expect((await repository.isBalanceVisible()).valueOrNull, isTrue);

      expect(
        (await repository.setBalanceVisible(visible: false)).isSuccess,
        isTrue,
      );

      // A new instance (next session) reads the stored value.
      final reopened = PreferencesRepositoryImpl(
        await SharedPreferences.getInstance(),
      );
      expect((await reopened.isBalanceVisible()).valueOrNull, isFalse);
    });
  });
}
