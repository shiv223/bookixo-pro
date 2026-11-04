import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Only data adapters call this mapper; raw responses are never retained.
abstract final class DataFailureMapper {
  static AppFailure map(
    Object error,
    StackTrace stack, {
    bool storage = false,
  }) {
    if (error is AppFailure) return error;
    if (storage) return const StorageFailure();
    if (error is FormatException || error is TypeError) {
      return const ContractFailure();
    }
    if (error is DioException) {
      if (error.error case final AppFailure failure) return failure;
      return switch (error.response?.statusCode) {
        400 || 422 => const ValidationFailure(),
        401 => const UnauthorizedFailure(),
        403 => const ForbiddenFailure(),
        404 => const NotFoundFailure(),
        409 => const ConflictFailure(),
        final int code when code >= 500 => const ServerFailure(),
        _ => switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.connectionError => const NetworkFailure(),
          _ => const UnknownFailure(),
        },
      };
    }
    return const UnknownFailure();
  }
}
