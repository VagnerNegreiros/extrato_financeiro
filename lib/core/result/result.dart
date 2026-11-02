import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:meta/meta.dart';

/// Outcome of an operation that can fail in an expected way.
///
/// Use a `switch` over [Success]/[Err] to handle both cases exhaustively.
@immutable
sealed class Result<T> {
  const new();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Err() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success() => null,
    Err(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onSuccess, R Function(Failure) onFailure) =>
      switch (this) {
        Success(:final value) => onSuccess(value),
        Err(:final failure) => onFailure(failure),
      };

  Result<U> map<U>(U Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Err(:final failure) => Err(failure),
  };

  Future<Result<U>> flatMapAsync<U>(
    Future<Result<U>> Function(T value) transform,
  ) async => switch (this) {
    Success(:final value) => await transform(value),
    Err(:final failure) => Err(failure),
  };
}

final class Success<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Err<T> extends Result<T> {
  const new(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Err($failure)';
}
