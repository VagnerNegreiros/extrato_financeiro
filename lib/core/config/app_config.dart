/// Which data source the app talks to.
///
/// * [dev]: deterministic local fixtures, no network or API key required.
/// * [prod]: live CoinGecko API.
enum AppFlavor { dev, prod }

/// Failure injected by the fake data source (dev flavor only), used to
/// demonstrate adverse scenarios without depending on the real API.
enum FakeFailure { none, network, rateLimit, server }

/// Thrown at startup when the build configuration is invalid. Failing fast
/// here is intentional: a misconfigured build must never reach the user.
final class InvalidConfigException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => 'InvalidConfigException: $message';
}

/// Build-time configuration read from `--dart-define-from-file`.
///
/// Values come from a git-ignored JSON file (see `config/env.example.json`).
/// They are embedded in the binary, so only low-risk keys (CoinGecko Demo)
/// may be provided this way.
final class AppConfig {
  const new _({
    required this.flavor,
    required this.coinGeckoBaseUri,
    required this.coinGeckoApiKey,
    required this.fakeFailure,
  });

  /// Reads the compile-time environment.
  factory fromEnvironment() => AppConfig.parse(
    flavor: const String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev'),
    coinGeckoBaseUrl: const String.fromEnvironment(
      'COINGECKO_BASE_URL',
      defaultValue: _defaultCoinGeckoBaseUrl,
    ),
    coinGeckoApiKey: const String.fromEnvironment('COINGECKO_API_KEY'),
    fakeFailure: const String.fromEnvironment(
      'FAKE_FAILURE',
      defaultValue: 'none',
    ),
  );

  /// Validates raw values. Exposed for tests.
  ///
  /// Every value is required on purpose: with defaults, the analyzer flags
  /// `String.fromEnvironment` arguments as redundant (it evaluates them to
  /// their default at analysis time) and `dart fix` would drop them.
  factory parse({
    required String flavor,
    required String coinGeckoBaseUrl,
    required String coinGeckoApiKey,
    required String fakeFailure,
  }) {
    final parsedFlavor = _parseEnum(AppFlavor.values, flavor, 'APP_FLAVOR');
    final parsedFailure = _parseEnum(
      FakeFailure.values,
      _normalizeEnumName(fakeFailure),
      'FAKE_FAILURE',
    );

    final uri = Uri.tryParse(coinGeckoBaseUrl.trim());
    if (uri == null || !uri.hasAuthority) {
      throw const InvalidConfigException('COINGECKO_BASE_URL is not a URL.');
    }
    if (uri.scheme != 'https') {
      throw const InvalidConfigException('COINGECKO_BASE_URL must use HTTPS.');
    }

    final apiKey = coinGeckoApiKey.trim();
    if (parsedFlavor == AppFlavor.prod && apiKey.isEmpty) {
      throw const InvalidConfigException(
        'COINGECKO_API_KEY is required for the prod flavor.',
      );
    }

    return AppConfig._(
      flavor: parsedFlavor,
      coinGeckoBaseUri: uri,
      coinGeckoApiKey: apiKey,
      fakeFailure: parsedFailure,
    );
  }

  static const _defaultCoinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  final AppFlavor flavor;
  final Uri coinGeckoBaseUri;
  final String coinGeckoApiKey;
  final FakeFailure fakeFailure;

  bool get usesFakeData => flavor == AppFlavor.dev;

  // Never expose the API key, even in debug output.
  @override
  String toString() =>
      'AppConfig(flavor: ${flavor.name}, baseUri: $coinGeckoBaseUri, '
      'apiKey: ${coinGeckoApiKey.isEmpty ? '<empty>' : '<redacted>'}, '
      'fakeFailure: ${fakeFailure.name})';

  static T _parseEnum<T extends Enum>(List<T> values, String raw, String key) {
    final name = raw.trim();
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw InvalidConfigException('Invalid $key: "$raw".');
  }

  // Accepts snake_case values from the env file (rate_limit -> rateLimit).
  static String _normalizeEnumName(String raw) => raw.trim().replaceAllMapped(
    RegExp('_([a-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
}
