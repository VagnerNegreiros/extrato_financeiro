import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:flutter/material.dart';

/// Runs a pull-to-refresh and, when it fails, explains why in a SnackBar
/// while the cached data stays on screen (RN-25).
Future<void> refreshWithFeedback(
  BuildContext context,
  Future<Result<Object?>> Function() refresh,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await refresh();
  if (result case Err(:final failure)) {
    final description = describeFailure(failure);
    messenger.showSnackBar(
      SnackBar(content: Text('${description.title}. ${description.message}')),
    );
  }
}
