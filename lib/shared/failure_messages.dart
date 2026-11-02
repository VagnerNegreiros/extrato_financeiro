import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:flutter/material.dart';

/// User-facing description of a [Failure], in pt-BR.
@immutable
final class FailureMessage {
  const new({required this.title, required this.message, required this.icon});

  final String title;
  final String message;
  final IconData icon;
}

/// Single place that turns failures into words, so every screen explains
/// the same problem the same way. Technical details never reach the user.
FailureMessage describeFailure(Failure failure) => switch (failure) {
  NetworkFailure() => const FailureMessage(
    title: 'Sem conexão',
    message: 'Verifique sua internet e tente novamente.',
    icon: Icons.wifi_off_rounded,
  ),
  TimeoutFailure() => const FailureMessage(
    title: 'A conexão está lenta',
    message: 'O serviço demorou para responder. Tente novamente.',
    icon: Icons.hourglass_empty_rounded,
  ),
  RateLimitFailure(:final retryAfter) => FailureMessage(
    title: 'Muitas requisições',
    message: retryAfter == null
        ? 'Aguarde alguns instantes e tente novamente.'
        : 'Aguarde ${_seconds(retryAfter)} e tente novamente.',
    icon: Icons.speed_rounded,
  ),
  ServerFailure(statusCode: 401 || 403) => const FailureMessage(
    title: 'Configuração inválida',
    message: 'Não foi possível autenticar no serviço de cotações.',
    icon: Icons.key_off_rounded,
  ),
  ServerFailure() => const FailureMessage(
    title: 'Serviço indisponível',
    message: 'O serviço de cotações está com instabilidade. Tente mais tarde.',
    icon: Icons.cloud_off_rounded,
  ),
  ParsingFailure() => const FailureMessage(
    title: 'Dados inesperados',
    message: 'Recebemos uma resposta inválida. Tente novamente mais tarde.',
    icon: Icons.report_gmailerrorred_rounded,
  ),
  CacheFailure() => const FailureMessage(
    title: 'Erro ao ler os dados',
    message: 'Não foi possível acessar os dados salvos no aparelho.',
    icon: Icons.storage_rounded,
  ),
  NotFoundFailure() => const FailureMessage(
    title: 'Não encontrado',
    message: 'Este item não existe ou não está mais disponível.',
    icon: Icons.search_off_rounded,
  ),
  UnexpectedFailure() => const FailureMessage(
    title: 'Algo deu errado',
    message: 'Tente novamente em instantes.',
    icon: Icons.error_outline_rounded,
  ),
};

String _seconds(Duration duration) {
  final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
  return seconds == 1 ? '1 segundo' : '$seconds segundos';
}
