import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import '../time/session_clock.dart';
import '../../features/auth/domain/session_access.dart';

/// One renewal after protected 401; only explicitly safe GETs are replayed.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.client, this.session, this.clock);
  final Dio client;
  final SessionAccess session;
  final SessionClock clock;
  static const safeRead = 'bookixo.safeRead';
  static const _retried = 'bookixo.retried';
  static const _generation = 'bookixo.generation';
  bool _excluded(RequestOptions request) =>
      request.path.endsWith('api/auth/signin') ||
      request.path.endsWith('api/auth/refresh');

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_excluded(options)) {
      handler.next(options);
      return;
    }
    final generation = session.generation;
    try {
      try {
        await session.ensureFresh();
      } on AppFailure {
        final current = session.currentSession;
        if (current == null || !current.tokens.usable(clock.now())) rethrow;
      }
      final current = session.currentSession;
      if (current == null ||
          generation != session.generation ||
          !current.tokens.usable(clock.now())) {
        throw const UnauthorizedFailure();
      }
      options.headers['Authorization'] = 'Bearer ${current.tokens.accessToken}';
      options.extra[_generation] = generation;
      handler.next(options);
    } on AppFailure catch (e, s) {
      handler.reject(
        DioException(requestOptions: options, error: e, stackTrace: s),
      );
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_excluded(response.requestOptions) &&
        response.requestOptions.extra[_generation] != session.generation) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          error: const UnauthorizedFailure(),
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final request = error.requestOptions;
    if (_excluded(request) || error.response?.statusCode != 401) {
      handler.next(error);
      return;
    }
    if (request.extra[_generation] != session.generation) {
      handler.reject(
        DioException(
          requestOptions: request,
          error: const UnauthorizedFailure(),
        ),
      );
      return;
    }
    try {
      if (request.extra[_retried] == true) {
        await session.logout();
        throw const UnauthorizedFailure();
      }
      final current = session.currentSession;
      if (current == null) throw const UnauthorizedFailure();
      final failedBearer = request.headers['Authorization'];
      try {
        // Another request may already have refreshed this exact failed token.
        if (failedBearer == 'Bearer ${current.tokens.accessToken}') {
          await session.ensureFresh(force: true);
        }
      } on AppFailure {
        if (request.extra[_generation] == session.generation) {
          await session.logout();
        }
        rethrow;
      }
      if (request.extra[_generation] != session.generation) {
        throw const UnauthorizedFailure();
      }
      if (request.method == 'GET' && request.extra[safeRead] == true) {
        request.extra[_retried] = true;
        handler.resolve(await client.fetch<Object?>(request));
      } else {
        // Session recovered; preserve input and let the user resubmit mutations.
        handler.reject(
          DioException(
            requestOptions: request,
            error: const UnauthorizedFailure(),
          ),
        );
      }
    } on DioException catch (e, s) {
      handler.reject(e.copyWith(stackTrace: s));
    } on AppFailure catch (e, s) {
      handler.reject(
        DioException(requestOptions: request, error: e, stackTrace: s),
      );
    }
  }
}
