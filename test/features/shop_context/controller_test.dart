import 'dart:async';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  test(
    'demo switch validates membership and resets on account replacement',
    () async {
      final auth = FakeAuthRepository()..restored = sampleSession();
      final shop = FakeShopRepository()
        ..result = ShopContext(const [Shop(15, 'A'), Shop(16, 'B')], 15);
      final container = ProviderContainer(
        overrides: [
          configProvider.overrideWithValue(
            AppConfig.parse('https://example.test', debug: true, demo: true),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          shopRepositoryProvider.overrideWithValue(shop),
          clockProvider.overrideWithValue(FakeClock()),
          menuCacheStoreProvider.overrideWithValue(
            MenuCacheStore(MemoryBackend()),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container.read(shopContextProvider.future);
      final selection = container.read(demoShopSelectionProvider.notifier);
      expect(container.read(demoShopSelectionProvider), 15);
      selection.select(16);
      expect(container.read(demoShopSelectionProvider), 16);
      selection.select(99);
      expect(container.read(demoShopSelectionProvider), 16);
      await container.read(authControllerProvider.notifier).logout();
      expect(container.read(demoShopSelectionProvider), isNull);
    },
  );
  test('legacy demo hook cannot bypass production selection', () async {
    final auth = FakeAuthRepository()..restored = sampleSession();
    final shop = FakeShopRepository()
      ..result = ShopContext(const [Shop(15, 'A'), Shop(16, 'B')], 15);
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(shop),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container.read(shopContextProvider.future);
    container.read(demoShopSelectionProvider.notifier).select(16);
    expect(container.read(demoShopSelectionProvider), 15);
  });
  test('superseded shop load cannot leak into new account', () async {
    final auth = FakeAuthRepository()..restored = sampleSession();
    final shop = FakeShopRepository()..gate = Completer();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(shop),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(shopContextProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(authControllerProvider.future);
    await flush();
    final oldGate = shop.gate;
    shop.gate = null;
    shop.result = ShopContext(const [Shop(20, 'New salon')], 20);
    auth.signInResult = Authenticated(sampleSession(userId: 'new-user'));
    await container
        .read(authControllerProvider.notifier)
        .signIn('new@example.test', 'test');
    await container.read(shopContextProvider.future);
    oldGate?.complete(ShopContext(const [Shop(15, 'Old salon')], 15));
    await flush();
    expect(container.read(shopContextProvider).requireValue?.primaryShopId, 20);
  });
}
