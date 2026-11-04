import 'dart:async';
import 'dart:convert';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/auth/data/auth_repository_impl.dart';
import 'package:bookixo_pro/features/auth/data/refresh_transport.dart';
import 'package:bookixo_pro/features/auth/data/secure_session_store.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/role_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../../support/fakes.dart';

void main() {
  test(
    'numeric user ID supports sign-in, refresh and secure restoration',
    () async {
      final body = {...authResponse(), 'userId': 5};
      final backend = MemoryBackend();
      final repository = AuthRepositoryImpl(
        stubClient(StubAdapter((_) => (status: 200, body: body))),
        SecureSessionStore(backend),
        DioRefreshTransport(
          stubClient(StubAdapter((_) => (status: 200, body: body))),
          FakeClock(),
        ),
        FakeClock(),
      );
      final signedIn = await repository.signIn('owner@example.test', 'test');
      final session = (signedIn as Authenticated).session;
      expect(session.identity.userId, '5');
      expect((await repository.restore())?.identity.userId, '5');
      final refreshed = await DioRefreshTransport(
        stubClient(StubAdapter((_) => (status: 200, body: body))),
        FakeClock(),
      ).refresh(session);
      final updated = (refreshed as Authenticated).session;
      expect(updated.identity.userId, '5');
      final store = SecureSessionStore(backend);
      await store.write(updated, () => true);
      expect((await store.read())?.identity.userId, '5');
    },
  );
  test('exact sign-in body, email trim, password unchanged; secure restore derives role', () async {
    final adapter = StubAdapter((_) => (status: 200, body: authResponse()));
    final backend = MemoryBackend();
    final store = SecureSessionStore(backend);
    final repository = AuthRepositoryImpl(
      stubClient(adapter),
      store,
      FakeRefresh(Authenticated(sampleSession())),
      FakeClock(),
    );
    expect(
      await repository.signIn(' owner@example.test ', ' pass '),
      isA<Authenticated>(),
    );
    expect(adapter.requests.single.path, 'api/auth/signin');
    expect(adapter.requests.single.data, {
      'identifier': 'owner@example.test',
      'password': ' pass ',
    });
    expect(backend.value, isNot(contains('password')));
    expect(backend.value, isNot(contains('"role"')));
    final restored = await repository.restore();
    expect(restored?.identity.role, AppRole.owner);
    expect(restored?.tokens.receivedAt, testNow);
  });
  test('challenge never persists tokens or challenge session', () async {
    final backend = MemoryBackend();
    final repository = AuthRepositoryImpl(
      stubClient(
        StubAdapter(
          (_) => (
            status: 200,
            body: {'challengeName': 'MFA', 'session': 'sensitive'},
          ),
        ),
      ),
      SecureSessionStore(backend),
      FakeRefresh(const ActionRequired()),
      FakeClock(),
    );
    expect(
      await repository.signIn('owner@example.test', 'test'),
      isA<ActionRequired>(),
    );
    expect(backend.value, isNull);
    expect(backend.writes, 0);
  });
  test('failed secure write never reports authenticated', () async {
    final backend = MemoryBackend()..writeFailure = const StorageFailure();
    final repository = AuthRepositoryImpl(
      stubClient(StubAdapter((_) => (status: 200, body: authResponse()))),
      SecureSessionStore(backend),
      FakeRefresh(const ActionRequired()),
      FakeClock(),
    );
    await expectLater(
      repository.signIn('owner@example.test', 'test'),
      throwsA(isA<StorageFailure>()),
    );
  });
  test('malformed bundle is typed failure, not signed out', () async {
    final backend = MemoryBackend()..value = '{"version":99}';
    await expectLater(
      SecureSessionStore(backend).read(),
      throwsA(isA<ContractFailure>()),
    );
    backend.value = 'not json';
    await expectLater(
      SecureSessionStore(backend).read(),
      throwsA(isA<ContractFailure>()),
    );
  });
  test('serialized write then logout cannot resurrect bundle', () async {
    final backend = MemoryBackend()..writeGate = Completer<void>();
    final repository = AuthRepositoryImpl(
      stubClient(StubAdapter((_) => (status: 200, body: authResponse()))),
      SecureSessionStore(backend),
      FakeRefresh(const ActionRequired()),
      FakeClock(),
    );
    final signIn = repository.signIn('owner@example.test', 'test');
    await flush();
    expect(backend.writes, 1);
    final logout = repository.logout();
    backend.writeGate?.complete();
    expect(await signIn, isA<Superseded>());
    await logout;
    expect(backend.value, isNull);
  });
  test('logout during remote sign-in prevents persistence', () async {
    final gate = Completer<({int status, Object? body})>();
    final backend = MemoryBackend();
    final repository = AuthRepositoryImpl(
      stubClient(StubAdapter((_) => gate.future)),
      SecureSessionStore(backend),
      FakeRefresh(const ActionRequired()),
      FakeClock(),
    );
    final signIn = repository.signIn('owner@example.test', 'test');
    await flush();
    await repository.logout();
    gate.complete((status: 200, body: authResponse()));
    expect(await signIn, isA<Superseded>());
    expect(backend.value, isNull);
  });
  test('logout during refresh prevents stale persistence', () async {
    final backend = MemoryBackend();
    final transport = FakeRefresh(Authenticated(sampleSession()))
      ..gate = Completer();
    final repository = AuthRepositoryImpl(
      stubClient(StubAdapter((_) => (status: 200, body: authResponse()))),
      SecureSessionStore(backend),
      transport,
      FakeClock(),
    );
    await repository.signIn('owner@example.test', 'test');
    final renewal = repository.refresh(sampleSession());
    await repository.logout();
    transport.gate?.complete(Authenticated(sampleSession(salt: 'old')));
    expect(await renewal, isA<Superseded>());
    expect(backend.value, isNull);
  });
  test(
    'rapid account replacement discards previous delayed response',
    () async {
      final old = Completer<({int status, Object? body})>();
      var requests = 0;
      final backend = MemoryBackend();
      final repository = AuthRepositoryImpl(
        stubClient(
          StubAdapter((_) {
            requests++;
            return requests == 1
                ? old.future
                : (status: 200, body: authResponse(userId: 'new'));
          }),
        ),
        SecureSessionStore(backend),
        FakeRefresh(const ActionRequired()),
        FakeClock(),
      );
      final first = repository.signIn('old@example.test', 'test');
      await flush();
      await repository.signIn('new@example.test', 'test');
      old.complete((status: 200, body: authResponse(userId: 'old')));
      expect(await first, isA<Superseded>());
      expect((await repository.restore())?.identity.userId, 'new');
    },
  );
  for (final status in [400, 401, 403, 404, 409, 422, 500]) {
    test('sign-in $status becomes sanitized typed failure', () async {
      final repository = AuthRepositoryImpl(
        stubClient(
          StubAdapter(
            (_) =>
                (status: status, body: {'message': 'sensitive server details'}),
          ),
        ),
        SecureSessionStore(MemoryBackend()),
        FakeRefresh(const ActionRequired()),
        FakeClock(),
      );
      await expectLater(
        repository.signIn('owner@example.test', 'test'),
        throwsA(isA<AppFailure>()),
      );
    });
  }
  test(
    'refresh exact camelCase body, no bearer, omission retention and rotation',
    () async {
      final old = sampleSession();
      for (final rotate in [false, true]) {
        final body = authResponse(refresh: 'rotated');
        if (!rotate) body.remove('refreshToken');
        final adapter = StubAdapter((_) => (status: 200, body: body));
        final result = await DioRefreshTransport(
          stubClient(adapter),
          FakeClock(),
        ).refresh(old);
        expect(adapter.requests.single.path, 'api/auth/refresh');
        expect(adapter.requests.single.data, {
          'email': old.identity.email,
          'refreshToken': old.tokens.refreshToken,
        });
        expect(
          adapter.requests.single.headers.containsKey('Authorization'),
          isFalse,
        );
        expect(
          (result as Authenticated).session.tokens.refreshToken,
          rotate ? 'rotated' : old.tokens.refreshToken,
        );
      }
    },
  );
  test('refresh cannot silently replace account', () async {
    final transport = DioRefreshTransport(
      stubClient(
        StubAdapter(
          (_) => (status: 200, body: authResponse(userId: 'different')),
        ),
      ),
      FakeClock(),
    );
    await expectLater(
      transport.refresh(sampleSession()),
      throwsA(isA<ContractFailure>()),
    );
  });
  test('store expiry bound survives restoration unchanged', () async {
    final backend = MemoryBackend();
    final store = SecureSessionStore(backend);
    await store.write(sampleSession(lifetime: 10), () => true);
    final stored = jsonDecode(backend.value ?? '{}') as Map<String, Object?>;
    expect(stored['version'], 1);
    final restored = await store.read();
    expect(
      restored?.tokens.earliestExpiry,
      testNow.add(const Duration(seconds: 10)),
    );
    expect(
      restored?.tokens.usable(testNow.add(const Duration(seconds: 11))),
      isFalse,
    );
  });
  test(
    'raw secure storage failures are typed and serialized queue recovers',
    () async {
      final backend = BrokenBackend();
      final store = SecureSessionStore(backend);
      await expectLater(store.read(), throwsA(isA<StorageFailure>()));
      await expectLater(
        store.write(sampleSession(), () => true),
        throwsA(isA<StorageFailure>()),
      );
      await expectLater(store.clear(), throwsA(isA<StorageFailure>()));
      backend.broken = false;
      expect(await store.write(sampleSession(), () => true), isTrue);
      expect(await store.read(), isNotNull);
    },
  );
}

class BrokenBackend extends MemoryBackend {
  bool broken = true;
  @override
  Future<String?> read() async {
    if (broken) throw PlatformException(code: 'test', message: 'sensitive');
    return super.read();
  }

  @override
  Future<void> write(String value) async {
    if (broken) throw PlatformException(code: 'test', message: 'sensitive');
    await super.write(value);
  }

  @override
  Future<void> delete() async {
    if (broken) throw MissingPluginException('sensitive');
    await super.delete();
  }
}
