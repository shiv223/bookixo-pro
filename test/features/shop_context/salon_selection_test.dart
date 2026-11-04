import 'dart:async';
import 'dart:convert';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:bookixo_pro/features/shop_context/data/salon_preference_repository_impl.dart';
import 'package:bookixo_pro/features/shop_context/domain/salon_preference_repository.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_selection_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_switch_guard.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class MemorySalonPreferences implements SalonPreferenceRepository {
  final values = <String, int>{};
  Completer<int?>? gate;
  AppFailure? readFailure;
  AppFailure? writeFailure;
  int reads = 0;
  @override
  Future<int?> read(String account) async {
    reads++;
    if (readFailure case final failure?) throw failure;
    return gate == null ? values[account] : gate?.future;
  }

  @override
  Future<void> write(
    String account,
    int shopId,
    bool Function() isCurrent,
  ) async {
    if (writeFailure case final failure?) throw failure;
    if (isCurrent()) values[account] = shopId;
  }
}

class MemorySalonBackend implements SalonPreferenceBackend {
  final values = <String, String>{};
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<String?> read(String key) async {
    if (fail) throw PlatformException(code: 'storage');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    await gate?.future;
    if (fail) throw PlatformException(code: 'storage');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

String accountKey(String user) => jsonEncode([user, null]);

void main() {
  late FakeAuthRepository auth;
  late FakeShopRepository shops;
  late MemorySalonPreferences preferences;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuthRepository()..restored = sampleSession();
    shops = FakeShopRepository()
      ..result = ShopContext(const [Shop(15, 'A'), Shop(16, 'B')], 15);
    preferences = MemorySalonPreferences();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(FakeClock()),
        shopRepositoryProvider.overrideWithValue(shops),
        salonPreferenceRepositoryProvider.overrideWithValue(preferences),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> boot() async {
    await container.read(authControllerProvider.future);
    await container.read(shopContextProvider.future);
    container.read(selectedShopProvider);
    await flush();
  }

  test(
    'restore last accessible, reject nonmember, rapid A B A revisions',
    () async {
      preferences.values[accountKey('5')] = 16;
      await boot();
      expect(container.read(selectedShopProvider)?.id, 16);
      final selection = container.read(salonSelectionProvider.notifier);
      final revision = container.read(scopeRevisionProvider);
      expect(selection.select(99), false);
      expect(selection.select(15), true);
      final next = container.read(scopeRevisionProvider);
      expect(selection.select(16), true);
      expect(container.read(scopeRevisionProvider), greaterThan(next));
      expect(next, greaterThan(revision));
      await flush();
      expect(preferences.values[accountKey('5')], 16);
    },
  );
  test('removed membership falls back to backend primary', () async {
    preferences.values[accountKey('5')] = 999;
    await boot();
    expect(container.read(selectedShopProvider)?.id, 15);
  });
  test('relaunch restores preference with new controller ownership', () async {
    await boot();
    container.read(salonSelectionProvider.notifier).select(16);
    await flush();
    container.dispose();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(FakeClock()),
        shopRepositoryProvider.overrideWithValue(shops),
        salonPreferenceRepositoryProvider.overrideWithValue(preferences),
      ],
    );
    await boot();
    expect(container.read(selectedShopProvider)?.id, 16);
    expect(preferences.reads, 2);
  });
  test('single auto and zero gates without consulting preferences', () async {
    shops.result = ShopContext(const [Shop(16, 'B')], 16);
    await boot();
    expect(container.read(selectedShopProvider)?.id, 16);
    expect(preferences.reads, 0);
    container.read(salonSelectionProvider);
    await flush();
    expect(preferences.values[accountKey('5')], 16);
    shops.result = ShopContext(const [], null);
    container.invalidate(shopContextProvider);
    await container.read(shopContextProvider.future);
    expect(container.read(selectedShopProvider), isNull);
  });
  test(
    'employee assigned primary, cannot restore or select owner branch',
    () async {
      auth.restored = sampleSession(groups: ['shop_employee']);
      preferences.values[accountKey('5')] = 16;
      await boot();
      expect(container.read(selectedShopProvider)?.id, 15);
      expect(preferences.reads, 0);
      expect(container.read(salonSelectionProvider.notifier).select(16), false);
    },
  );
  test('storage read/write failures nonblocking and Retry persists', () async {
    preferences.readFailure = const StorageFailure();
    await boot();
    expect(container.read(selectedShopProvider)?.id, 15);
    expect(
      container.read(salonSelectionProvider).notice,
      isA<StorageFailure>(),
    );
    preferences.writeFailure = const StorageFailure();
    container.read(salonSelectionProvider.notifier).select(16);
    await flush();
    expect(container.read(selectedShopProvider)?.id, 16);
    expect(
      container.read(salonSelectionProvider).notice,
      isA<StorageFailure>(),
    );
    preferences.writeFailure = null;
    container.read(salonSelectionProvider.notifier).retryPreference();
    await flush();
    expect(preferences.values[accountKey('5')], 16);
    expect(container.read(salonSelectionProvider).notice, isNull);
  });
  test(
    'rotation retains selection; logout restores only same account',
    () async {
      await boot();
      container.read(salonSelectionProvider.notifier).select(16);
      await flush();
      final revision = container.read(scopeRevisionProvider);
      await container
          .read(authControllerProvider.notifier)
          .ensureFresh(force: true);
      expect(container.read(selectedShopProvider)?.id, 16);
      expect(container.read(scopeRevisionProvider), revision);
      expect(preferences.reads, 1);
      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(selectedShopProvider), isNull);
      await container
          .read(authControllerProvider.notifier)
          .signIn('same@example.test', 'test');
      await container.read(shopContextProvider.future);
      container.read(selectedShopProvider);
      await flush();
      expect(container.read(selectedShopProvider)?.id, 16);
      auth.signInResult = Authenticated(sampleSession(userId: 'other'));
      await container
          .read(authControllerProvider.notifier)
          .signIn('other@example.test', 'test');
      await container.read(shopContextProvider.future);
      container.read(selectedShopProvider);
      await flush();
      expect(container.read(selectedShopProvider)?.id, 15);
    },
  );
  test('stale account preference read cannot replace new account', () async {
    final gate = Completer<int?>();
    preferences.gate = gate;
    await boot();
    expect(container.read(selectedShopProvider), isNull);
    preferences.gate = null;
    auth.signInResult = Authenticated(sampleSession(userId: 'other'));
    await container
        .read(authControllerProvider.notifier)
        .signIn('other@example.test', 'test');
    await container.read(shopContextProvider.future);
    container.read(selectedShopProvider);
    await flush();
    gate.complete(16);
    await flush();
    expect(container.read(selectedShopProvider)?.id, 15);
  });
  test(
    'dirty confirmation and active mutation gate cannot be bypassed',
    () async {
      await boot();
      final guard = container.read(salonSwitchGuardProvider);
      final owner = Object();
      guard.register(owner, () => true);
      final controller = container.read(salonSelectionProvider.notifier);
      expect(controller.select(16), false);
      final finish = guard.beginRequest();
      expect(controller.select(16, discardConfirmed: true), false);
      finish();
      expect(controller.select(16, discardConfirmed: true), true);
      guard.unregister(owner);
    },
  );
  test('serial secure writes rollback stale ownership and preserve account isolation', () async {
    final backend = MemorySalonBackend();
    final repository = SalonPreferenceRepositoryImpl(backend);
    await repository.write('a', 15, () => true);
    final gate = Completer<void>();
    backend.gate = gate;
    var current = true;
    final old = repository.write('a', 16, () => current);
    await flush();
    current = false;
    final next = repository.write('a', 17, () => true);
    final other = repository.write('b', 25, () => true);
    gate.complete();
    await Future.wait([old, next, other]);
    expect(await repository.read('a'), 17);
    expect(await repository.read('b'), 25);
    backend.fail = true;
    await expectLater(repository.read('a'), throwsA(isA<StorageFailure>()));
    await expectLater(
      repository.write('a', 99, () => true),
      throwsA(isA<StorageFailure>()),
    );
  });
  test(
    'stale completed secure write alone rolls back to prior preference',
    () async {
      final backend = MemorySalonBackend();
      final repository = SalonPreferenceRepositoryImpl(backend);
      await repository.write('same-account', 15, () => true);
      backend.gate = Completer<void>();
      var current = true;
      final pending = repository.write('same-account', 16, () => current);
      await flush();
      current = false;
      backend.gate?.complete();
      await pending;
      expect(
        await SalonPreferenceRepositoryImpl(backend).read('same-account'),
        15,
      );
    },
  );
}
