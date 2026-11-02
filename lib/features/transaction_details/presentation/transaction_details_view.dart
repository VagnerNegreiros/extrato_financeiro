import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/time/date_formatter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_state.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_view_model.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:extrato_financeiro/shared/widgets/info_row.dart';
import 'package:extrato_financeiro/shared/widgets/state_views.dart';
import 'package:extrato_financeiro/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionDetailsView extends ConsumerWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = transactionDetailsViewModelProvider(id);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);

    final Widget body;
    if (state.isLoading) {
      body = const SingleChildScrollView(child: LoadingView(itemCount: 4));
    } else if (state.isNotFound) {
      body = Center(
        child: EmptyView(
          icon: Icons.search_off_rounded,
          title: 'Transação não encontrada',
          message: 'Ela pode ter sido removida ou o link está incorreto.',
          actionLabel: 'Voltar',
          onAction: context.back,
        ),
      );
    } else if (state.transaction case final transaction?) {
      body = _Details(
        transaction: transaction,
        state: state,
        viewModel: viewModel,
      );
    } else {
      body = Center(
        child: ErrorView(failure: state.failure!, onRetry: viewModel.retry),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da transação'),
        leading: BackButton(onPressed: context.back),
      ),
      body: body,
    );
  }
}

class _Details extends ConsumerWidget {
  const new({
    required this.transaction,
    required this.state,
    required this.viewModel,
  });

  final Transaction transaction;
  final TransactionDetailsState state;
  final TransactionDetailsViewModel viewModel;

  Future<void> _copyId(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: transaction.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Identificador copiado')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = ref.watch(dateFormatterProvider);
    final theme = Theme.of(context);
    final metadata = transaction.metadata;
    final symbol = metadata.assetSymbol;
    final noEffect =
        transaction.status == TransactionStatus.failed ||
        transaction.status == TransactionStatus.reversed;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        _Header(transaction: transaction, dates: dates, noEffect: noEffect),
        const Divider(height: AppSpacing.xl),
        InfoRow(
          label: 'Identificador',
          value: transaction.id,
          trailing: IconButton(
            tooltip: 'Copiar identificador',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyId(context),
          ),
        ),
        InfoRow(
          label: 'Data e hora',
          value: dates.dateTime(transaction.occurredAt),
        ),
        InfoRow(label: 'Tipo', value: transaction.direction.label),
        InfoRow(label: 'Categoria', value: transaction.category.label),
        InfoRow(
          label: 'Status',
          child: Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(transaction.status),
          ),
        ),
        InfoRow(
          label: 'Valor',
          child: AmountText(
            transaction.amount,
            direction: transaction.direction,
            strikethrough: noEffect,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (symbol != null) InfoRow(label: 'Ativo', value: symbol),
        if (metadata.assetQuantity case final quantity?)
          InfoRow(
            label: 'Quantidade',
            value: '${formatDecimal(quantity)} ${symbol ?? ''}'.trim(),
          ),
        if (metadata.unitPrice case final unitPrice?)
          InfoRow(
            label: 'Preço unitário na operação',
            child: AmountText(unitPrice, style: theme.textTheme.bodyLarge),
          ),
        if (metadata.counterparty case final counterparty?)
          InfoRow(label: 'Contraparte', value: counterparty),
        InfoRow(
          label: 'Registrado em (UTC)',
          value: dates.isoUtc(transaction.occurredAt),
        ),
        if (state.quoteStatus != QuoteStatus.notApplicable) ...[
          const Divider(height: AppSpacing.xl),
          _QuoteSection(
            state: state,
            symbol: symbol ?? '',
            unitPrice: metadata.unitPrice,
            onRetry: viewModel.retryQuote,
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const new({
    required this.transaction,
    required this.dates,
    required this.noEffect,
  });

  final Transaction transaction;
  final AppDateFormatter dates;
  final bool noEffect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = transaction.direction;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: direction.color(context).withValues(alpha: 0.12),
            child: Icon(
              direction.icon,
              color: direction.color(context),
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            transaction.description,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AmountText(
              transaction.amount,
              direction: direction,
              strikethrough: noEffect,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatusChip(transaction.status),
          if (noEffect) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Esta transação não afeta o saldo.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteSection extends StatelessWidget {
  const new({
    required this.state,
    required this.symbol,
    required this.unitPrice,
    required this.onRetry,
  });

  final TransactionDetailsState state;
  final String symbol;
  final Money? unitPrice;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = state.quote;
    final content = switch (state.quoteStatus) {
      QuoteStatus.loading => const Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppSpacing.md),
          Text('Buscando cotação…'),
        ],
      ),
      QuoteStatus.loaded when quote != null => _QuoteValues(
        quote: quote,
        unitPrice: unitPrice,
      ),
      _ => Row(
        children: [
          Expanded(
            child: Text(
              describeFailure(state.quoteFailure ?? const UnexpectedFailure())
                  .title,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Cotação atual do $symbol',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          content,
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Informativa: a cotação não altera o saldo da conta.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteValues extends StatelessWidget {
  const new({required this.quote, required this.unitPrice});

  final MarketQuote quote;
  final Money? unitPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change24h = quote.change24hPercent;
    final reference = unitPrice;
    final sinceTrade = reference == null
        ? null
        : quote.changeSincePercent(reference);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AmountText(
          quote.price,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (change24h != null)
          Text(
            'Últimas 24h: ${formatPercent(change24h)}',
            style: theme.textTheme.bodyMedium,
          ),
        if (sinceTrade != null)
          Text(
            'Desde a operação: ${formatPercent(sinceTrade)}',
            style: theme.textTheme.bodyMedium,
          ),
      ],
    );
  }
}
