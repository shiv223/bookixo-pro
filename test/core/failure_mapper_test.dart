import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/errors/data_failure_mapper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = RequestOptions(path: '/test');
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('$type maps to friendly NetworkFailure', () {
      final failure = DataFailureMapper.map(
        DioException(
          requestOptions: request,
          type: type,
          message: 'secret details',
        ),
        StackTrace.empty,
      );
      expect(failure, isA<NetworkFailure>());
      expect(failure.toString(), isNot(contains('secret')));
    });
  }
  test('typed failure identity is retained with no raw message leak', () {
    const failure = ForbiddenFailure();
    expect(DataFailureMapper.map(failure, StackTrace.empty), same(failure));
    expect(
      DataFailureMapper.map(
        DioException(requestOptions: request, error: failure),
        StackTrace.empty,
      ),
      same(failure),
    );
  });
  test('storage and malformed response failures are typed', () {
    expect(
      DataFailureMapper.map(
        PlatformException(code: 'secret'),
        StackTrace.empty,
        storage: true,
      ),
      isA<StorageFailure>(),
    );
    expect(
      DataFailureMapper.map(const FormatException('secret'), StackTrace.empty),
      isA<ContractFailure>(),
    );
    expect(
      DataFailureMapper.map(Exception('secret'), StackTrace.empty),
      isA<UnknownFailure>(),
    );
  });
}
