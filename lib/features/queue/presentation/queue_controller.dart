import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../data/booking_api_repository.dart';
import '../data/mock_queue_repository.dart';
import '../data/shop_features_repository_impl.dart';
import '../domain/queue_item.dart';
import '../domain/queue_realtime_repository.dart';
import '../domain/shop_features_repository.dart';

const queueRefreshInterval = queueRealtimePollInterval;

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  final revision = ref.watch(scopeRevisionProvider);
  final config = ref.watch(configProvider);
  if (config.demo) {
    // A new in-memory adapter is created for every account/shop scope so demo
    // customer names cannot outlive logout or leak into another shop.
    ref.watch(menuScopeProvider);
    return MockQueueRepository();
  }
  final identity = ref.watch(
    authControllerProvider.select((auth) => auth.asData?.value.identity),
  );
  final menu = ref.watch(menuControllerProvider).asData?.value?.snapshot;
  final shop = ref.watch(selectedShopProvider);
  final keys = menu?.keys ?? const <String>{};
  final features =
      ref.watch(enabledShopFeaturesProvider).asData?.value ?? const <String>{};
  return BookingApiRepository(
    client: ref.watch(protectedClientProvider),
    shopId: shop?.id,
    userEmail: identity?.email,
    isCurrent: () => ref.mounted && ref.read(scopeRevisionProvider) == revision,
    canCreateWalkIn:
        features.contains(bookingCreateFeatureKey) ||
        keys.contains(bookingCreateFeatureKey),
  );
});

final shopFeaturesRepositoryProvider = Provider<ShopFeaturesRepository>(
  (ref) => ShopFeaturesRepositoryImpl(ref.watch(protectedClientProvider)),
);

/// Server-enabled feature keys for the selected shop
/// (`GET api/shop-features/me`). While loading or after a failure the set is
/// treated as empty, so gated actions stay hidden.
final enabledShopFeaturesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(scopeRevisionProvider);
  final shopId = ref.watch(selectedShopProvider.select((shop) => shop?.id));
  if (shopId == null || shopId <= 0) return const <String>{};
  return ref.watch(shopFeaturesRepositoryProvider).loadEnabledFeatures(shopId);
}, retry: (_, _) => null);

final queueIsMockProvider = Provider<bool>(
  (ref) => ref.watch(queueRepositoryProvider) is MockQueueRepository,
);

/// Feature availability is supplied by the repository; the UI never infers it
/// from a locally stored role.
final canCreateWalkInProvider = Provider<bool>(
  (ref) => ref.watch(queueRepositoryProvider).canCreateWalkIn,
);

/// Each permitted queue tab is fetched independently and never returns prices.
final queueItemsProvider = FutureProvider.autoDispose
    .family<List<QueueItem>, String>((ref, tab) async {
      final menu = ref.watch(menuControllerProvider).asData?.value;
      if (menu == null ||
          !menu.projection.tabs.any((allowed) => allowed.selector == tab)) {
        return [];
      }
      return ref.watch(queueRepositoryProvider).load(tab);
    }, retry: (_, _) => null);
