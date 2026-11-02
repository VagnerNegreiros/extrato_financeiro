import 'package:extrato_financeiro/core/result/result.dart';

/// User preferences persisted across sessions (RN-29).
abstract interface class PreferencesRepository {
  /// Defaults to `true` when never set.
  Future<Result<bool>> isBalanceVisible();

  Future<Result<void>> setBalanceVisible({required bool visible});
}
