import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/preferences/domain/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive UI preferences. Anything secret would go to secure
/// storage instead (see DATABASE.md).
final class PreferencesRepositoryImpl implements PreferencesRepository {
  new(this._preferences);

  static const balanceVisibleKey = 'balance_visible';

  final SharedPreferences _preferences;

  @override
  Future<Result<bool>> isBalanceVisible() async {
    try {
      return Success(_preferences.getBool(balanceVisibleKey) ?? true);
    } on Object catch (error) {
      return Err(CacheFailure(error.toString()));
    }
  }

  @override
  Future<Result<void>> setBalanceVisible({required bool visible}) async {
    try {
      final saved = await _preferences.setBool(balanceVisibleKey, visible);
      return saved
          ? const Success(null)
          : const Err(CacheFailure('preference not saved'));
    } on Object catch (error) {
      return Err(CacheFailure(error.toString()));
    }
  }
}
