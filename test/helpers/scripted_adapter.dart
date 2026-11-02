import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef ScriptedReply = Future<ResponseBody> Function(
  RequestOptions options,
  Future<void>? cancelFuture,
);

/// HTTP adapter that answers from a queue of scripted replies and records
/// every request, so the real Dio stack (interceptors included) is tested.
final class ScriptedAdapter implements HttpClientAdapter {
  final _replies = <ScriptedReply>[];
  final requests = <RequestOptions>[];

  void enqueue(ScriptedReply reply) => _replies.add(reply);

  void enqueueJson(
    Object? body, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) => enqueue(
    (_, _) async => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    ),
  );

  void enqueueStatus(
    int status, {
    Map<String, List<String>> headers = const {},
  }) => enqueueJson(
    {'error': 'status $status'},
    status: status,
    headers: headers,
  );

  void enqueueConnectionError() => enqueue(
    (options, _) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'scripted connection error',
    ),
  );

  /// Never answers; completes only when the request is cancelled.
  void enqueueHang() => enqueue((options, cancelFuture) async {
    await (cancelFuture ?? Completer<void>().future);
    throw DioException.requestCancelled(
      requestOptions: options,
      reason: 'cancelled',
    );
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    if (_replies.isEmpty) {
      throw StateError('No scripted reply for ${options.uri}');
    }
    return _replies.removeAt(0)(options, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
