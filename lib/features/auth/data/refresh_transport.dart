import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/time/session_clock.dart';
import '../domain/auth_models.dart';
import 'sign_in_response_dto.dart';

/// Renewal uses a dedicated client; never intercepted recursively.
abstract interface class RefreshTransport {
  Future<SignInOutcome> refresh(AuthSession session);
}

class DioRefreshTransport implements RefreshTransport {
  DioRefreshTransport(this.client, this.clock);
  final Dio client;
  final SessionClock clock;
  @override
  Future<SignInOutcome> refresh(AuthSession session) async {
    try {
      final response = await client.post<Object?>(
        'api/auth/refresh',
        data: {
          'email': session.identity.email,
          'refreshToken': session.tokens.refreshToken,
        },
      );
      final outcome = SignInResponseDto.parse(response.data)
          .toOutcome(clock.now(), oldRefresh: session.tokens.refreshToken);
      if (outcome is Authenticated &&
          (outcome.session.identity.userId != session.identity.userId ||
              outcome.session.identity.email != session.identity.email)) {
        throw const ContractFailure();
      }
      return outcome;
    } on DioException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s), s);
    }
  }
}
