import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:meta/meta.dart';

/// Converts a JSON number to [Decimal] at the boundary, so no arithmetic is
/// ever done in `double`. `double.toString()` yields the shortest
/// representation that round-trips, i.e. the literal sent by the API.
Decimal? decimalFromJson(Object? value) => switch (value) {
  final int v => Decimal.fromInt(v),
  final double v when v.isFinite => Decimal.tryParse(v.toString()),
  _ => null,
};

@immutable
final class PricePoint {
  const new(this.timestamp, this.price);

  /// UTC instant of the price.
  final DateTime timestamp;

  /// Price in BRL, always positive.
  final Decimal price;
}

/// `GET /coins/{id}/market_chart` (only `prices` is used).
@immutable
final class MarketChartDto {
  const new({required this.prices, this.discardedPoints = 0});

  /// Defensive parsing: malformed points are dropped and counted; the whole
  /// payload is rejected only when its shape is wrong or most points are
  /// invalid, which signals an API change rather than noise.
  factory fromJson(Object? json, {required DateTime nowUtc}) {
    if (json is! Map) {
      throw const ParsingException('market_chart: expected an object');
    }
    final raw = json['prices'];
    if (raw is! List) {
      throw const ParsingException('market_chart: "prices" is missing');
    }

    final latestAllowed = nowUtc.add(const Duration(days: 1));
    final points = <PricePoint>[];
    for (final entry in raw) {
      final point = _parsePoint(entry, latestAllowed);
      if (point != null) points.add(point);
    }

    final discarded = raw.length - points.length;
    if (points.isEmpty || discarded * 2 > raw.length) {
      throw ParsingException(
        'market_chart: $discarded of ${raw.length} points are invalid',
      );
    }
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return MarketChartDto(
      prices: List.unmodifiable(points),
      discardedPoints: discarded,
    );
  }

  /// Bitcoin's first trade happened in 2009; anything older is corrupted.
  static final _earliestAllowed = DateTime.utc(2009);

  final List<PricePoint> prices;
  final int discardedPoints;

  static PricePoint? _parsePoint(Object? entry, DateTime latestAllowed) {
    if (entry is! List || entry.length < 2) return null;
    final millis = entry[0];
    if (millis is! num || !millis.isFinite) return null;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      millis.toInt(),
      isUtc: true,
    );
    if (timestamp.isBefore(_earliestAllowed) ||
        timestamp.isAfter(latestAllowed)) {
      return null;
    }
    final price = decimalFromJson(entry[1]);
    if (price == null || price <= Decimal.zero) return null;
    return PricePoint(timestamp, price);
  }
}

/// `GET /simple/price?ids={id}&vs_currencies=brl&include_24hr_change=true`.
@immutable
final class SimplePriceDto {
  const new({required this.price, this.change24hPercent});

  factory fromJson(Object? json, {required String assetId}) {
    if (json is! Map) {
      throw const ParsingException('simple/price: expected an object');
    }
    final asset = json[assetId];
    if (asset is! Map) {
      throw ParsingException('simple/price: "$assetId" is missing');
    }
    final price = decimalFromJson(asset['brl']);
    if (price == null || price <= Decimal.zero) {
      throw const ParsingException('simple/price: invalid "brl" price');
    }
    return SimplePriceDto(
      price: price,
      change24hPercent: decimalFromJson(asset['brl_24h_change']),
    );
  }

  final Decimal price;
  final Decimal? change24hPercent;
}
