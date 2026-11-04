import 'dart:convert';

import '../../../core/time/session_clock.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'sign_in_response_dto.dart';

/// Explicit demo only. No network, persisted credentials or price data.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.clock);
  final SessionClock clock;
  @override
  Future<AuthSession?> restore() async => null;
  @override
  Future<void> logout() async {}
  @override
  Future<SignInOutcome> signIn(String identifier, String password) async {
    final email = identifier.contains('@') ? identifier : 'owner@example.test';
    if (email == 'challenge@example.test') return const ActionRequired();
    final groups = switch (email) {
      'owner@example.test' => ['OWNER'],
      'employee@example.test' => ['shop_employee'],
      _ => <String>[],
    };
    return _session(email, groups);
  }

  @override
  Future<SignInOutcome> refresh(AuthSession session) async =>
      _session(session.identity.email, session.identity.groups);

  SignInOutcome _session(String email, List<String> groups) {
    final now = clock.now();
    final exp =
        now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    String jwt(Map<String, Object?> payload) =>
        'e30.${base64Url.encode(utf8.encode(jsonEncode(payload)))}.demo';
    return SignInResponseDto.parse({
      'accessToken': jwt({'exp': exp}),
      'idToken': jwt({'exp': exp, 'cognito:groups': groups}),
      'refreshToken': 'mock-only',
      'tokenType': 'Bearer',
      'expiresIn': 3600,
      'userId': 'mock-user',
      'email': email,
    }).toOutcome(now);
  }
}
