import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 2, 4);
  final day1 = DateTime.utc(2026, 11).millisecondsSinceEpoch;
  final day2 = DateTime.utc(2026, 11, 2).millisecondsSinceEpoch;

  MarketChartDto parse(Object? json) =>
      MarketChartDto.fromJson(json, nowUtc: now);

  group('decimalFromJson', () {
    test('keeps the literal digits of JSON numbers', () {
      expect(
        decimalFromJson(430086.1803941016),
        Decimal.parse('430086.1803941016'),
      );
      expect(decimalFromJson(7), Decimal.fromInt(7));
      expect(decimalFromJson(1e-7), Decimal.parse('0.0000001'));
    });

    test('rejects non-numbers and non-finite values', () {
      expect(decimalFromJson('12'), isNull);
      expect(decimalFromJson(null), isNull);
      expect(decimalFromJson(double.nan), isNull);
      expect(decimalFromJson(double.infinity), isNull);
    });
  });

  group('MarketChartDto (defensive parsing)', () {
    test('sorts points and ignores unknown fields', () {
      final chart = parse({
        'prices': [
          [day2, 2.5],
          [day1, 1],
        ],
        'unexpected': {'field': true},
      });
      expect(chart.prices.map((p) => p.timestamp), [
        DateTime.utc(2026, 11),
        DateTime.utc(2026, 11, 2),
      ]);
      expect(
        () => chart.prices.add(chart.prices.first),
        throwsUnsupportedError,
      );
    });

    test('drops a minority of malformed points and counts them', () {
      final chart = parse({
        'prices': [
          [day1, 10],
          [day2, 11],
          [day2 + 1, 12],
          [day2 + 2, -1], // negative price
          ['x', 1], // bad timestamp
        ],
      });
      expect(chart.prices, hasLength(3));
      expect(chart.discardedPoints, 2);
    });

    test('drops implausible timestamps', () {
      final chart = parse({
        'prices': [
          [day1, 10],
          [day2, 10],
          [DateTime.utc(2008).millisecondsSinceEpoch, 10],
        ],
      });
      expect(chart.discardedPoints, 1);
      expect(
        () => parse({
          'prices': [
            [now.add(const Duration(days: 3)).millisecondsSinceEpoch, 10],
          ],
        }),
        throwsA(isA<ParsingException>()),
      );
    });

    test('rejects payloads with the wrong shape', () {
      for (final json in <Object?>[
        null,
        'text',
        [1, 2],
        <String, Object?>{},
        {'prices': 'nope'},
        {'prices': <Object?>[]},
        {
          'prices': [
            [day1],
            [day2, 0],
            [day2, 'x'],
          ],
        },
      ]) {
        expect(
          () => parse(json),
          throwsA(isA<ParsingException>()),
          reason: '$json',
        );
      }
    });

    test('rejects payloads where most points are invalid', () {
      expect(
        () => parse({
          'prices': [
            [day1, 1],
            [day2, null],
            [day2, -3],
          ],
        }),
        throwsA(isA<ParsingException>()),
      );
    });
  });

  group('SimplePriceDto', () {
    test('parses price and optional change', () {
      final dto = SimplePriceDto.fromJson(const {
        'bitcoin': {'brl': 100.5},
      }, assetId: 'bitcoin');
      expect(dto.price, Decimal.parse('100.5'));
      expect(dto.change24hPercent, isNull);
    });

    test('rejects missing assets and invalid prices', () {
      for (final json in <Object?>[
        null,
        {
          'ethereum': {'brl': 1},
        },
        {'bitcoin': 'x'},
        {
          'bitcoin': {'brl': 0},
        },
        {
          'bitcoin': {'usd': 10},
        },
      ]) {
        expect(
          () => SimplePriceDto.fromJson(json, assetId: 'bitcoin'),
          throwsA(isA<ParsingException>()),
          reason: '$json',
        );
      }
    });
  });
}
