import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/domain/menu_repository.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository(this.store, this.clock);
  final MenuCacheStore store;
  final FakeClock clock;
  Set<String> keys = {'bookings-pending', 'shopdashboard'};
  Set<String> setupChildren = {};
  AppFailure? failure;
  Completer<Set<String>>? gate;
  int calls = 0;
  @override
  Future<MenuSnapshot> fetch(MenuScope scope) async {
    calls++;
    if (failure case final AppFailure error) throw error;
    return MenuSnapshot(
      scope,
      await gate?.future ?? keys,
      clock.now(),
      shopSetupChildren: setupChildren,
    );
  }

  @override
  Future<MenuSnapshot?> read(MenuScope scope) => store.read(scope);
  @override
  Future<void> write(MenuSnapshot snapshot, bool Function() current) =>
      store.write(snapshot, current);
  @override
  Future<void> clear() => store.clear();
}

void main() {
  late FakeClock clock;
  late MemoryBackend backend;
  late MenuCacheStore store;
  late FakeMenuRepository menu;
  late FakeAuthRepository auth;
  late FakeShopRepository shop;
  late ProviderContainer container;
  setUp(() {
    clock = FakeClock();
    backend = MemoryBackend();
    store = MenuCacheStore(backend);
    menu = FakeMenuRepository(store, clock);
    auth = FakeAuthRepository()..restored = sampleSession(userId: '5');
    shop = FakeShopRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(clock),
        shopRepositoryProvider.overrideWithValue(shop),
        menuCacheStoreProvider.overrideWithValue(store),
        menuRepositoryProvider.overrideWithValue(menu),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<MenuView?> boot() async {
    await container.read(authControllerProvider.future);
    await container.read(shopContextProvider.future);
    await flush();
    final view = await container.read(menuControllerProvider.future);
    await flush();
    return view;
  }

  test(
    'rapid identical-scope switch rejects late menu and cache write',
    () async {
      await boot();
      final gate = Completer<Set<String>>();
      menu.gate = gate;
      final pending = container.read(menuControllerProvider.notifier).refresh();
      await flush();
      menu.gate = null;
      menu.keys = {'bookings-pending'};
      final revision = container.read(salonSwitchRevisionProvider.notifier);
      revision.advance();
      revision.advance();
      await container.read(menuControllerProvider.future);
      gate.complete({'shop-offers-2'});
      await pending;
      await flush();
      expect(
        container.read(menuControllerProvider).asData?.value?.snapshot.keys,
        {'bookings-pending'},
      );
      expect((await store.read(const MenuScope('5', null, 15)))?.keys, {
        'bookings-pending',
      });
    },
  );

  test(
    'startup refresh-first, 59/60 boundary; manual bypass; single flight',
    () async {
      await boot();
      final controller = container.read(menuControllerProvider.notifier);
      clock.advance(const Duration(seconds: 59));
      await controller.refresh(resume: true);
      expect(menu.calls, 1);
      clock.advance(const Duration(seconds: 1));
      await controller.refresh(resume: true);
      expect(menu.calls, 2);
      menu.gate = Completer();
      final a = controller.refresh();
      final b = controller.refresh();
      expect(identical(a, b), isTrue);
      await flush();
      expect(menu.calls, 3);
      menu.gate?.complete({'shopdashboard'});
      await a;
      expect(
        container.read(menuControllerProvider).asData?.value?.snapshot.keys,
        {'shopdashboard'},
      );
    },
  );
  test('older scoped cache fallback and resume attempt throttle', () async {
    const scope = MenuScope('5', null, 15);
    await store.write(
      MenuSnapshot(scope, {
        'shopdashboard',
      }, testNow.subtract(const Duration(days: 8))),
      () => true,
    );
    menu.failure = const NetworkFailure();
    final view = await boot();
    expect(view?.stale, isTrue);
    expect(view?.snapshot.keys, {'shopdashboard'});
    final controller = container.read(menuControllerProvider.notifier);
    await controller.refresh(resume: true);
    final calls = menu.calls;
    clock.advance(const Duration(seconds: 59));
    await controller.refresh(resume: true);
    expect(menu.calls, calls);
    clock.advance(const Duration(seconds: 1));
    await controller.refresh(resume: true);
    expect(menu.calls, calls + 1);
    await controller.refresh();
    expect(menu.calls, calls + 2);
  });
  test('wrong user/shop cache never used on cold network failure', () async {
    await store.write(
      MenuSnapshot(const MenuScope('6', null, 15), {'shopdashboard'}, testNow),
      () => true,
    );
    menu.failure = const NetworkFailure();
    await expectLater(boot(), throwsA(isA<NetworkFailure>()));
  });
  test('fresh zero replaces cache even when persistence fails', () async {
    await boot();
    menu.keys = {};
    backend.writeFailure = const StorageFailure();
    await container.read(menuControllerProvider.notifier).refresh();
    final view = container.read(menuControllerProvider).asData?.value;
    expect(view?.projection.landing, '/no-access');
    expect(view?.notice, isA<StorageFailure>());
    menu.failure = const NetworkFailure();
    await container.read(menuControllerProvider.notifier).refresh();
    expect(
      container.read(menuControllerProvider).asData?.value?.snapshot.keys,
      isEmpty,
    );
  });
  test('fresh zero durable replacement survives a new store', () async {
    await boot();
    menu.keys = {};
    await container.read(menuControllerProvider.notifier).refresh();
    expect(
      (await MenuCacheStore(backend).read(const MenuScope('5', null, 15)))
          ?.keys,
      isEmpty,
    );
  });
  test('403 and 401 fail closed instead of saved access', () async {
    await boot();
    for (final failure in [
      const ForbiddenFailure(),
      const UnauthorizedFailure(),
    ]) {
      menu.failure = failure;
      await container.read(menuControllerProvider.notifier).refresh();
      expect(container.read(menuControllerProvider).hasError, isTrue);
      expect(container.read(menuControllerProvider).asData, isNull);
    }
  });
  test('nonrecoverable menu failures do not reuse saved access', () async {
    await boot();
    for (final failure in [
      const ValidationFailure(),
      const NotFoundFailure(),
      const ConflictFailure(),
    ]) {
      menu.failure = failure;
      await container.read(menuControllerProvider.notifier).refresh();
      expect(container.read(menuControllerProvider).hasError, isTrue);
    }
  });
  test('rotation renews credentials without shop/menu reloading', () async {
    await boot();
    auth.refreshResult = Authenticated(
      sampleSession(userId: '5', salt: 'rotation'),
    );
    await container
        .read(authControllerProvider.notifier)
        .ensureFresh(force: true);
    await flush();
    expect(menu.calls, 1);
    expect(shop.calls, 1);
    expect(
      container
          .read(menuControllerProvider)
          .asData
          ?.value
          ?.snapshot
          .scope
          .userId,
      '5',
    );
  });
  test(
    'logout during fetch cannot recreate cache; deletion error stays locked',
    () async {
      await boot();
      menu.gate = Completer();
      final refresh = container.read(menuControllerProvider.notifier).refresh();
      await flush();
      backend.deleteFailure = const StorageFailure();
      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(authControllerProvider).hasError, isTrue);
      expect(container.read(menuScopeProvider), isNull);
      menu.gate?.complete({'shopdashboard'});
      await refresh;
      backend.deleteFailure = null;
      await container.read(authControllerProvider.notifier).retry();
      expect(backend.value, isNull);
      expect(
        container.read(authControllerProvider).asData?.value.identity,
        isNull,
      );
    },
  );
  test('logout during write awaits serialized deletion', () async {
    await boot();
    backend.writeGate = Completer();
    final refresh = container.read(menuControllerProvider.notifier).refresh();
    await flush();
    final logout = container.read(authControllerProvider.notifier).logout();
    expect(container.read(menuScopeProvider), isNull);
    backend.writeGate?.complete();
    await Future.wait([refresh, logout]);
    expect(backend.value, isNull);
  });
  test('account replacement discards in-flight prior-user response', () async {
    await boot();
    menu.gate = Completer();
    final refresh = container.read(menuControllerProvider.notifier).refresh();
    await flush();
    final oldGate = menu.gate;
    menu.gate = null;
    menu.keys = {'shop-memberships'};
    auth.signInResult = Authenticated(sampleSession(userId: '6'));
    await container
        .read(authControllerProvider.notifier)
        .signIn('new@example.test', 'test');
    await container.read(shopContextProvider.future);
    await flush();
    await container.read(menuControllerProvider.future);
    oldGate?.complete({'shopdashboard'});
    await refresh;
    expect(
      container
          .read(menuControllerProvider)
          .asData
          ?.value
          ?.snapshot
          .scope
          .userId,
      '6',
    );
    expect((await store.read(const MenuScope('6', null, 15)))?.keys, {
      'shop-memberships',
    });
  });
  test(
    'cache corruption and read errors surface after fresh network data',
    () async {
      backend.value = 'not-json';
      await boot();
      expect(
        container.read(menuControllerProvider).asData?.value?.notice,
        isA<ContractFailure>(),
      );
      expect(
        container.read(menuControllerProvider).asData?.value?.snapshot.keys,
        menu.keys,
      );
      expect(await store.read(const MenuScope('5', null, 15)), isNotNull);
    },
  );
  test(
    'cache read failure without network data remains an explicit gate',
    () async {
      backend.readFailure = const StorageFailure();
      menu.failure = const ServerFailure();
      await expectLater(boot(), throwsA(isA<ServerFailure>()));
      expect(container.read(menuControllerProvider).hasError, isTrue);
    },
  );
  test('logout locks immediately while deletion is pending', () async {
    await boot();
    backend.deleteGate = Completer();
    final controller = container.read(authControllerProvider.notifier);
    final logout = controller.logout();
    expect(container.read(menuScopeProvider), isNull);
    await expectLater(
      controller.signIn('new@example.test', 'sample'),
      throwsA(isA<StorageFailure>()),
    );
    backend.deleteGate?.complete();
    await logout;
    expect(backend.value, isNull);
  });
  test(
    'demo shop replacement isolates both data and stale in-flight results',
    () async {
      container.dispose();
      shop.result = ShopContext(const [Shop(15, 'A'), Shop(16, 'B')], 15);
      container = ProviderContainer(
        overrides: [
          configProvider.overrideWithValue(
            AppConfig.parse('https://example.test', debug: true, demo: true),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          clockProvider.overrideWithValue(clock),
          shopRepositoryProvider.overrideWithValue(shop),
          menuCacheStoreProvider.overrideWithValue(store),
          menuRepositoryProvider.overrideWithValue(menu),
        ],
      );
      await boot();
      menu.gate = Completer();
      final refresh = container.read(menuControllerProvider.notifier).refresh();
      await flush();
      final oldGate = menu.gate;
      menu.gate = null;
      menu.keys = {'shop-offers-2'};
      container.read(demoShopSelectionProvider.notifier).select(16);
      await flush();
      await container.read(menuControllerProvider.future);
      await flush();
      oldGate?.complete({'shopdashboard'});
      await refresh;
      expect(
        container
            .read(menuControllerProvider)
            .asData
            ?.value
            ?.snapshot
            .scope
            .shopId,
        16,
      );
      expect((await store.read(const MenuScope('5', null, 16)))?.keys, {
        'shop-offers-2',
      });
      expect(await store.read(const MenuScope('5', null, 15)), isNull);
    },
  );
  test(
    'login to same account refreshes rather than treating it as token rotation',
    () async {
      await boot();
      auth.signInResult = Authenticated(sampleSession());
      await container
          .read(authControllerProvider.notifier)
          .signIn('owner@example.test', 'sample');
      await container.read(shopContextProvider.future);
      await flush();
      await container.read(menuControllerProvider.future);
      await flush();
      expect(menu.calls, 2);
    },
  );
}
