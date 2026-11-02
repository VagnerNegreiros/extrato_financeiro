import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:flutter/material.dart';

/// Skeleton shown while the first data loads. Shapes mimic the real
/// content so the layout does not jump when it arrives.
class LoadingView extends StatelessWidget {
  const new({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
      ),
    );

    return Semantics(
      label: 'Carregando',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < itemCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundColor: color),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(double.infinity, 14),
                          const SizedBox(height: AppSpacing.sm),
                          bar(120, 10),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    bar(72, 14),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centered icon + title + message + optional action, shared by the empty
/// and error states.
class MessageView extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    this.icon = Icons.receipt_long_rounded,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: icon,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

/// Error state with a retry action; the message comes from
/// [describeFailure], never from the exception itself.
class ErrorView extends StatelessWidget {
  const new({required this.failure, required this.onRetry, super.key});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final description = describeFailure(failure);
    return Semantics(
      liveRegion: true,
      child: MessageView(
        icon: description.icon,
        title: description.title,
        message: description.message,
        actionLabel: 'Tentar novamente',
        onAction: onRetry,
      ),
    );
  }
}
