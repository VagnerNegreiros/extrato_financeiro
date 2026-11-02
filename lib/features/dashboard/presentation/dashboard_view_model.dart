import 'dart:async';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/security/biometric_authenticator.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/dashboard_state.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(
      DashboardViewModel.new,
    );

/// Dashboard ViewModel: reads the summary from the cache and reloads it
/// whenever a sync brings new data. It never talks to the network itself.
class DashboardViewModel extends Notifier<DashboardState> {
  /// Latest-wins guard: results of superseded loads are discarded.
  int _loadVersion = 0;

  @override
  DashboardState build() {
    ref.listen<AsyncValue<SyncInfo>>(syncInfoProvider, (_, next) {
      final info = next.value;
      if (info == null) return;
      final previous = state.syncInfo;
      state = state.copyWith(syncInfo: info);
      if (info.lastSuccessAt != previous.lastSuccessAt) unawaited(_load());
    });
    unawaited(Future.microtask(_initialize));
    return const DashboardState();
  }

  Future<void> _initialize() async {
    // The listener only sees changes; pick up a sync state that already
    // exists (e.g. the view model was recreated after the first sync).
    final current = ref.read(syncInfoProvider).value;
    if (current != null) state = state.copyWith(syncInfo: current);
    final visible = await ref.read(balanceVisibilityProvider).load();
    if (!ref.mounted) return;
    state = state.copyWith(isBalanceVisible: visible);
    await _load();
  }

  Future<void> selectPeriod(PeriodSelection period) async {
    if (period == state.period) return;
    state = state.copyWith(period: period);
    await _load();
  }

  /// RN-29/30: hiding is immediate; revealing asks for biometrics (or the
  /// device lock) when the device has one. The choice is persisted.
  ///
  /// Returns `false` when the user did not confirm their identity.
  Future<bool> toggleBalanceVisibility() async {
    final visible = !state.isBalanceVisible;
    if (visible) {
      final result = await ref
          .read(biometricAuthenticatorProvider)
          .authenticate(reason: 'Confirme sua identidade para exibir o saldo');
      if (!ref.mounted || result == BiometricResult.denied) return false;
    }
    state = state.copyWith(isBalanceVisible: visible);
    await ref.read(balanceVisibilityProvider).save(visible: visible);
    return true;
  }

  /// Pull-to-refresh. The returned result lets the view report a failure
  /// while the cached data stays on screen.
  Future<Result<SyncInfo>> refresh() =>
      ref.read(syncCoordinatorProvider).refresh();

  Future<void> retry() async {
    if (state.failure != null) await _load();
    if (state.syncInfo.lastFailure != null || !state.syncInfo.hasData) {
      await refresh();
    }
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    final result = await ref.read(getDashboardSummaryProvider)(state.period);
    if (!ref.mounted || version != _loadVersion) return;
    state = switch (result) {
      Success(value: final summary) => state.copyWith(
        summary: summary,
        failure: null,
      ),
      Err(:final failure) => state.copyWith(failure: failure),
    };
  }
}
