import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/shop_context/data/shop_context_repository_impl.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeClock clock;
  late ProviderContainer container;
  late AuthController controller;
  setUp(() async {
    repository = FakeAuthRepository()..restored = sampleSession();
    clock = FakeClock();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
      ],
    );
    await container.read(authControllerProvider.future);
    controller = container.read(authControllerProvider.notifier);
  });
  tearDown(() => container.dispose());
  Dio protected(StubAdapter adapter) {
    final client = stubClient(adapter);
    client.interceptors.add(AuthInterceptor(client, controller, clock));
    addTearDown(() => client.close());
    return client;
  }

  final safe = Options(extra: {AuthInterceptor.safeRead: true});

  test(
    'shop exact endpoint receives access Bearer, never refresh token',
    () async {
      final adapter = StubAdapter((request) {
        expect(
          request.headers['Authorization'],
          'Bearer ${sampleSession().tokens.accessToken}',
        );
        expect(
          request.headers['Authorization'],
          isNot(contains('test-refresh')),
        );
        return (
          status: 200,
          body: {
            'shops': [
              {'id': 15, 'name': 'Test salon'},
            ],
            'primaryShopId': 15,
            'primaryShopName': 'Test salon',
          },
        );
      });
      final result = await ShopContextRepositoryImpl(protected(adapter)).load();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, 'api/users/my-shop-context');
      expect(result.primaryShopId, 15);
    },
  );
  test(
    'safe GET 401 renews once then replays with updated access token',
    () async {
      var calls = 0;
      final adapter = StubAdapter(
        (_) => (status: ++calls == 1 ? 401 : 200, body: {}),
      );
      await protected(adapter).get<Object?>('protected', options: safe);
      expect(repository.renewals, 1);
      expect(calls, 2);
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer ${controller.currentSession?.tokens.accessToken}',
      );
    },
  );
  test(
    'concurrent protected 401s share renewal and replay only reads',
    () async {
      repository.refreshGate = Completer();
      var calls = 0;
      final client = protected(
        StubAdapter((_) => (status: ++calls <= 2 ? 401 : 200, body: {})),
      );
      final first = client.get<Object?>('protected', options: safe);
      final second = client.get<Object?>('protected', options: safe);
      await repository.refreshStarted.future;
      expect(repository.renewals, 1);
      repository.refreshGate?.complete(
        Authenticated(sampleSession(salt: 'renewed')),
      );
      await Future.wait([first, second]);
      expect(calls, 4);
      expect(repository.renewals, 1);
    },
  );
  test('second 401 logs out without a renewal loop', () async {
    final adapter = StubAdapter((_) => (status: 401, body: {}));
    await expectLater(
      protected(adapter).get<Object?>('protected', options: safe),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests.length, 2);
    expect(repository.renewals, 1);
    expect(repository.logouts, 1);
    expect(controller.currentSession, isNull);
  });
  test('failed 401 renewal clears even on transient network failure', () async {
    repository.refreshFailure = const NetworkFailure();
    final adapter = StubAdapter((_) => (status: 401, body: {}));
    await expectLater(
      protected(adapter).get<Object?>('protected', options: safe),
      throwsA(isA<DioException>()),
    );
    expect(repository.logouts, 1);
    expect(adapter.requests.length, 1);
  });
  test('403 is typed ForbiddenFailure without renewal', () async {
    final adapter = StubAdapter((_) => (status: 403, body: {}));
    await expectLater(
      ShopContextRepositoryImpl(protected(adapter)).load(),
      throwsA(isA<ForbiddenFailure>()),
    );
    expect(repository.renewals, 0);
    expect(repository.logouts, 0);
  });
  for (final path in ['payment', 'claim', 'save']) {
    test('$path mutation recovers session but is never replayed', () async {
      final adapter = StubAdapter((_) => (status: 401, body: {}));
      await expectLater(
        protected(adapter).post<Object?>(path, data: {'sample': true}),
        throwsA(isA<DioException>()),
      );
      expect(repository.renewals, 1);
      expect(adapter.requests.length, 1);
      expect(repository.logouts, 0);
    });
  }
  for (final path in ['api/auth/signin', 'api/auth/refresh']) {
    test('$path is excluded from bearer injection and 401 recovery', () async {
      final adapter = StubAdapter((_) => (status: 401, body: {}));
      await expectLater(
        protected(adapter).post<Object?>(path),
        throwsA(isA<DioException>()),
      );
      expect(repository.renewals, 0);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  }
  test('unmarked GET is not silently replayed', () async {
    final adapter = StubAdapter((_) => (status: 401, body: {}));
    await expectLater(
      protected(adapter).get<Object?>('protected'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests.length, 1);
  });
  test('logout discards in-flight shop response', () async {
    final gate = Completer<({int status, Object? body})>();
    final client = protected(StubAdapter((_) => gate.future));
    final load = client.get<Object?>('protected', options: safe);
    final assertion = expectLater(load, throwsA(isA<DioException>()));
    await flush();
    await controller.logout();
    gate.complete((status: 200, body: {}));
    await assertion;
    expect(controller.currentSession, isNull);
  });
}
