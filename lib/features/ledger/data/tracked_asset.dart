/// Crypto assets whose market data feeds the ledger.
enum TrackedAsset {
  bitcoin(id: 'bitcoin', symbol: 'BTC', displayName: 'Bitcoin'),
  ethereum(id: 'ethereum', symbol: 'ETH', displayName: 'Ethereum'),
  solana(id: 'solana', symbol: 'SOL', displayName: 'Solana');

  new({required this.id, required this.symbol, required this.displayName});

  /// CoinGecko coin id.
  final String id;
  final String symbol;
  final String displayName;
}
