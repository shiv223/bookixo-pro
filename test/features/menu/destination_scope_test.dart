import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/destination_scope_provider.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'controller_test.dart' show FakeMenuRepository;

void main() {
  for (final groups in [
    ['shop_employee'],
    ['shop_owner'],
  ]) {
    test(
      'exact new keys allow supported server role $groups and revoke safely',
      () async {
        final clock = FakeClock();
        final store = MenuCacheStore(MemoryBackend());
        final menu = FakeMenuRepository(store, clock)
          ..keys = {'shop-services-list', 'users-shop', 'shop-setup'};
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository()..restored = sampleSession(groups: groups),
            ),
            shopRepositoryProvider.overrideWithValue(FakeShopRepository()),
            clockProvider.overrideWithValue(clock),
            menuCacheStoreProvider.overrideWithValue(store),
            menuRepositoryProvider.overrideWithValue(menu),
          ],
        );
        addTearDown(container.dispose);
        await container.read(authControllerProvider.future);
        await container.read(shopContextProvider.future);
        await flush();
        await container.read(menuControllerProvider.future);
        for (final key in menu.keys) {
          expect(
            container.read(destinationScopeProvider(key))?.menu.shopId,
            15,
          );
        }
        final previous = container.read(destinationScopeProvider('users-shop'));
        container.read(salonSwitchRevisionProvider.notifier).advance();
        await container.read(menuControllerProvider.future);
        // The snapshot is published before its serialized cache write finishes.
        await flush();
        final next = container.read(destinationScopeProvider('users-shop'));
        expect(next?.revision, isNot(previous?.revision));
        menu.keys = {'USERS-SHOP', ' shop-services-list '};
        await container.read(menuControllerProvider.notifier).refresh();
        expect(container.read(destinationScopeProvider('users-shop')), isNull);
        expect(
          container.read(destinationScopeProvider('shop-services-list')),
          isNull,
        );
        await container.read(authControllerProvider.notifier).logout();
        expect(container.read(destinationScopeProvider('users-shop')), isNull);
      },
    );
  }
}
