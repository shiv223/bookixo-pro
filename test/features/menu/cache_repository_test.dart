import 'dart:async';
import 'dart:convert';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/data/menu_repository_impl.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'projection_test.dart' show node;

void main() {
  const scope = MenuScope('5', 'subject', 15);
  test(
    'v2 persists Setup edges; v1 flat snapshots never invent edges',
    () async {
      final backend = MemoryBackend();
      final store = MenuCacheStore(backend);
      await store.write(
        MenuSnapshot(
          scope,
          {'shop-setup', 'shop-logo'},
          testNow,
          shopSetupChildren: {'shop-logo'},
        ),
        () => true,
      );
      expect((await store.read(scope))?.shopSetupChildren, {'shop-logo'});
      final bundle = jsonDecode(backend.value ?? '') as Map<String, Object?>;
      expect(bundle['version'], 2);
      bundle['version'] = 1;
      bundle.remove('shopSetupChildren');
      backend.value = jsonEncode(bundle);
      final old = await store.read(scope);
      expect(old?.keys, {'shop-setup', 'shop-logo'});
      expect(old?.shopSetupChildren, isEmpty);
      await store.write(old ?? MenuSnapshot(scope, {}, testNow), () => true);
      expect((await store.read(scope))?.shopSetupChildren, isEmpty);
    },
  );
  test('v2 rejects absent or malformed Setup edges', () async {
    final backend = MemoryBackend();
    final store = MenuCacheStore(backend);
    await store.write(MenuSnapshot(scope, {'shop-setup'}, testNow), () => true);
    final bundle = jsonDecode(backend.value ?? '') as Map<String, Object?>;
    for (final children in [
      null,
      'workday',
      [1],
      ['workday'],
    ]) {
      backend.value = jsonEncode({...bundle, 'shopSetupChildren': children});
      await expectLater(store.read(scope), throwsA(isA<ContractFailure>()));
    }
  });
  test(
    'durable normalized cache rejects wrong account/shop and corruption',
    () async {
      final backend = MemoryBackend();
      final store = MenuCacheStore(backend);
      await store.write(
        MenuSnapshot(scope, {'shopdashboard'}, testNow),
        () => true,
      );
      expect((await MenuCacheStore(backend).read(scope))?.keys, {
        'shopdashboard',
      });
      expect(await store.read(const MenuScope('6', 'subject', 15)), isNull);
      expect(await store.read(const MenuScope('5', 'subject', 16)), isNull);
      backend.value = '{"version":1}';
      await expectLater(store.read(scope), throwsA(isA<ContractFailure>()));
    },
  );
  test(
    'clear serialized after write and rejects queued stale writes',
    () async {
      final backend = MemoryBackend()..writeGate = Completer();
      final store = MenuCacheStore(backend);
      final write = store.write(
        MenuSnapshot(scope, {'shopdashboard'}, testNow),
        () => true,
      );
      await flush();
      final clear = store.clear();
      final stale = store.write(
        MenuSnapshot(scope, {'shopdashboard'}, testNow),
        () => false,
      );
      backend.writeGate?.complete();
      await Future.wait([write, clear, stale]);
      expect(backend.value, isNull);
    },
  );
  test('clear error propagated; later retry removes durable data', () async {
    final backend = MemoryBackend()
      ..value = 'old'
      ..deleteFailure = const StorageFailure();
    final store = MenuCacheStore(backend);
    await expectLater(store.clear(), throwsA(isA<StorageFailure>()));
    backend.deleteFailure = null;
    await store.clear();
    expect(backend.value, isNull);
  });
  test(
    'exact protected menu GET shopId and access Bearer; 403 typed',
    () async {
      final clock = FakeClock();
      final backend = MemoryBackend();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()..restored = sampleSession(userId: '5'),
          ),
          clockProvider.overrideWithValue(clock),
          menuCacheStoreProvider.overrideWithValue(MenuCacheStore(backend)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      var forbidden = false;
      final adapter = StubAdapter((request) {
        expect(request.path, 'api/navigation/me');
        expect(request.method, 'GET');
        expect(request.queryParameters, {'shopId': 15});
        expect(
          request.headers['Authorization'],
          'Bearer ${sampleSession(userId: '5').tokens.accessToken}',
        );
        return (
          status: forbidden ? 403 : 200,
          body: [
            node('shopdashboard'),
            node('shop-setup', [node('workday')]),
          ],
        );
      });
      final client = stubClient(adapter);
      client.interceptors.add(
        AuthInterceptor(
          client,
          container.read(authControllerProvider.notifier),
          clock,
        ),
      );
      addTearDown(client.close);
      final repo = MenuRepositoryImpl(client, MenuCacheStore(backend), clock);
      final snapshot = await repo.fetch(scope);
      expect(snapshot.keys, {'shopdashboard', 'shop-setup', 'workday'});
      expect(snapshot.shopSetupChildren, {'workday'});
      forbidden = true;
      await expectLater(repo.fetch(scope), throwsA(isA<ForbiddenFailure>()));
    },
  );
  for (final revoked in [false, true]) {
    test('menu 401 uses bounded auth recovery; revoked=$revoked', () async {
      final clock = FakeClock();
      final backend = MemoryBackend();
      final store = MenuCacheStore(backend);
      await store.write(
        MenuSnapshot(scope, {'shopdashboard'}, testNow),
        () => true,
      );
      final auth = FakeAuthRepository()
        ..restored = sampleSession()
        ..refreshResult = Authenticated(sampleSession(salt: 'renewed'));
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          clockProvider.overrideWithValue(clock),
          menuCacheStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      var calls = 0;
      final adapter = StubAdapter(
        (_) => (
          status: ++calls == 1 || revoked ? 401 : 200,
          body: [node('shopdashboard')],
        ),
      );
      final client = stubClient(adapter);
      client.interceptors.add(
        AuthInterceptor(
          client,
          container.read(authControllerProvider.notifier),
          clock,
        ),
      );
      addTearDown(client.close);
      final repository = MenuRepositoryImpl(client, store, clock);
      if (revoked) {
        await expectLater(
          repository.fetch(scope),
          throwsA(isA<UnauthorizedFailure>()),
        );
        expect(backend.value, isNull);
        expect(
          container.read(authControllerProvider).asData?.value.identity,
          isNull,
        );
      } else {
        expect((await repository.fetch(scope)).keys, {'shopdashboard'});
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer ${sampleSession(salt: 'renewed').tokens.accessToken}',
        );
      }
      expect(auth.renewals, 1);
      expect(calls, 2);
    });
  }
  test('invalid selected shop never sends a menu request', () async {
    final adapter = StubAdapter((_) => (status: 200, body: []));
    final client = stubClient(adapter);
    addTearDown(client.close);
    final repository = MenuRepositoryImpl(
      client,
      MenuCacheStore(MemoryBackend()),
      FakeClock(),
    );
    await expectLater(
      repository.fetch(const MenuScope('5', null, 0)),
      throwsA(isA<ContractFailure>()),
    );
    expect(adapter.requests, isEmpty);
  });
}
