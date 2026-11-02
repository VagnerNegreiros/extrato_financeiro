import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the banner should say, derived from connectivity and sync state.
enum SyncBannerKind { none, offline, failed, stale }

SyncBannerKind syncBannerKind({
  required bool isOnline,
  required SyncInfo info,
  required DateTime nowUtc,
}) {
  // Without cached data the screen itself shows the offline/error state.
  if (!info.hasData) return SyncBannerKind.none;
  if (!isOnline || info.lastFailure is NetworkFailure) {
    return SyncBannerKind.offline;
  }
  if (info.lastFailure != null) return SyncBannerKind.failed;
  if (info.isStale(nowUtc)) return SyncBannerKind.stale;
  return SyncBannerKind.none;
}

/// Tells the user they are looking at cached data that may be outdated
/// (RN-25), and why.
class SyncStatusBanner extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(syncInfoProvider).value ?? SyncInfo.never;
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final now = ref.watch(clockProvider).nowUtc();
    final kind = syncBannerKind(isOnline: isOnline, info: info, nowUtc: now);
    if (kind == SyncBannerKind.none) return const SizedBox.shrink();

    final lastSync = ref
        .watch(dateFormatterProvider)
        .dateTime(info.lastSuccessAt!);
    final (icon, text) = switch (kind) {
      SyncBannerKind.offline => (
        Icons.wifi_off_rounded,
        'Você está offline. Exibindo dados de $lastSync.',
      ),
      SyncBannerKind.failed => (
        Icons.sync_problem_rounded,
        '${describeFailure(info.lastFailure!).title}. '
            'Exibindo dados de $lastSync.',
      ),
      SyncBannerKind.stale => (
        Icons.update_rounded,
        'Os dados podem estar desatualizados (atualizados em $lastSync).',
      ),
      SyncBannerKind.none => throw StateError('unreachable'),
    };

    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colors.onSecondaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSecondaryContainer),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(syncCoordinatorProvider).refresh(),
                child: const Text('Atualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
