import 'package:bookixo_pro/features/auth/domain/login_identifier.dart';
import 'package:bookixo_pro/features/auth/data/auth_repository_impl.dart';
import 'package:bookixo_pro/features/auth/data/refresh_transport.dart';
import 'package:bookixo_pro/features/auth/data/secure_session_store.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  for (final value in [
    'owner@example.test',
    ' owner@example.test ',
    '9876543210',
    '6987654321',
    '919876543210',
    '+919876543210',
    '+91 (987) 654-3210',
    '(987) 654-3210',
    '+12345678',
    '+123456789012345',
    '+44 (7700) 900-123',
  ]) {
    test('accepts staff identifier $value', () {
      expect(LoginIdentifier.isValid(value), true);
    });
  }
  for (final value in [
    '',
    'owner',
    'a@b',
    'a @b.test',
    '5876543210',
    '91987654321',
    '+915876543210',
    '+91987654321',
    '+9198765432100',
    '+0123456789',
    '447700900123',
    '+1234567',
    '+1234567890123456',
    '+44/7700900123',
    '+44\t7700900123',
    '++447700900123',
  ]) {
    test('rejects staff identifier $value', () {
      expect(LoginIdentifier.isValid(value), false);
    });
  }
  for (final identifier in [' owner@example.test ', ' +91 (987) 654-3210 ']) {
    test(
      'exact identifier payload and canonical refresh: $identifier',
      () async {
        final signin = StubAdapter((_) => (status: 200, body: authResponse()));
        final refresh = StubAdapter((_) => (status: 200, body: authResponse()));
        final repository = AuthRepositoryImpl(
          stubClient(signin),
          SecureSessionStore(MemoryBackend()),
          DioRefreshTransport(stubClient(refresh), FakeClock()),
          FakeClock(),
        );
        final result = await repository.signIn(identifier, ' password ');
        final session = (result as Authenticated).session;
        expect(signin.requests.single.data, {
          'identifier': identifier.trim(),
          'password': ' password ',
        });
        expect(session.identity.email, 'owner@example.test');
        await repository.refresh(session);
        expect(refresh.requests.single.data, {
          'email': 'owner@example.test',
          'refreshToken': 'test-refresh',
        });
        expect(
          (await repository.restore())?.identity.email,
          'owner@example.test',
        );
      },
    );
  }
}
