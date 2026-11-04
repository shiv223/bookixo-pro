import 'package:dio/dio.dart';

import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/time/session_clock.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'refresh_transport.dart';
import 'secure_session_store.dart';
import 'sign_in_response_dto.dart';

/// Owns generation-safe durable authentication transactions.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.client, this.store, this.transport, this.clock);
  final Dio client;
  final SecureSessionStore store;
  final RefreshTransport transport;
  final SessionClock clock;
  int _generation = 0;

  @override
  Future<SignInOutcome> signIn(String identifier, String password) async {
    final generation = ++_generation;
    // Replacing an account cannot leave the previous account restorable.
    await store.clear();
    if (generation != _generation) return const Superseded();
    try {
      final response = await client.post<Object?>(
        'api/auth/signin',
        data: {'identifier': identifier.trim(), 'password': password},
      );
      final outcome = SignInResponseDto.parse(response.data)
          .toOutcome(clock.now());
      return await _persist(outcome, generation);
    } on DioException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s), s);
    }
  }

  @override
  Future<AuthSession?> restore() async {
    final generation = _generation;
    final session = await store.read();
    return generation == _generation ? session : null;
  }

  @override
  Future<SignInOutcome> refresh(AuthSession session) async {
    final generation = _generation;
    final outcome = await transport.refresh(session);
    return _persist(outcome, generation);
  }

  Future<SignInOutcome> _persist(SignInOutcome outcome, int generation) async {
    if (generation != _generation) return const Superseded();
    if (outcome is Authenticated) {
      final written = await store.write(
        outcome.session,
        () => generation == _generation,
      );
      if (!written) return const Superseded();
    } else if (outcome is ActionRequired) {
      await store.clear();
      if (generation != _generation) return const Superseded();
    }
    return outcome;
  }

  @override
  Future<void> logout() {
    ++_generation;
    return store.clear();
  }
}
