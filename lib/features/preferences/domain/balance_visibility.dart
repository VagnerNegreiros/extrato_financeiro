import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/preferences/domain/preferences_repository.dart';

/// Hide/show balance preference (RN-29).
final class BalanceVisibility {
  const new(this._repository);

  final PreferencesRepository _repository;

  /// Falls back to visible when the preference cannot be read: failing
  /// open here only affects privacy on screen, never the data itself.
  Future<bool> load() async =>
      (await _repository.isBalanceVisible()).valueOrNull ?? true;

  Future<Result<void>> save({required bool visible}) =>
      _repository.setBalanceVisible(visible: visible);
}
