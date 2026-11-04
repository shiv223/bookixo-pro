import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../data/shop_context_repository_impl.dart';
import '../domain/shop_context.dart';
import '../domain/shop_context_repository.dart';
import 'salon_switch_guard.dart';
import '../../menu/presentation/scope_revision_provider.dart';

final protectedClientProvider = Provider((ref) {
  final client = createDio(ref.watch(configProvider));
  client.interceptors.add(
    AuthInterceptor(
      client,
      ref.read(authControllerProvider.notifier),
      ref.watch(clockProvider),
    ),
  );
  ref.onDispose(() => client.close(force: true));
  return client;
});
final shopRepositoryProvider = Provider<ShopContextRepository>((ref) {
  if (ref.watch(configProvider).demo) return const MockShopContextRepository();
  return ShopContextRepositoryImpl(ref.watch(protectedClientProvider));
});

/// Rebuilt on session state changes; Riverpod discards superseded loads.
final shopContextProvider = FutureProvider<ShopContext?>((ref) async {
  final scope = ref.watch(
    authControllerProvider.select(
      (auth) => (
        blocked:
            auth.isLoading ||
            auth.hasError ||
            auth.asData?.value.locked == true,
        userId: auth.asData?.value.identity?.userId,
        subject: auth.asData?.value.identity?.subject,
        role: auth.asData?.value.identity?.role,
        ownership: auth.asData?.value.ownership,
      ),
    ),
  );
  if (scope.blocked ||
      scope.userId == null ||
      scope.role == null ||
      !RolePolicy.supports(scope.role ?? AppRole.unknown)) {
    return null;
  }
  return ref.watch(shopRepositoryProvider).load();
}, retry: (_, _) => null);

/// Demo selection resets on account replacement, not token rotation.
final demoShopSelectionProvider = NotifierProvider<DemoShopSelection, int?>(
  DemoShopSelection.new,
);

class DemoShopSelection extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(
      authControllerProvider.select(
        (auth) => (
          blocked: auth.isLoading || auth.hasError,
          ownership: auth.asData?.value.ownership,
          userId: auth.asData?.value.identity?.userId,
          subject: auth.asData?.value.identity?.subject,
        ),
      ),
    );
    return ref.watch(shopContextProvider).asData?.value?.primaryShopId;
  }

  void select(int id, {bool discardConfirmed = false}) {
    if (!ref.read(configProvider).demo) return;
    final guard = ref.read(salonSwitchGuardProvider);
    final role = ref.read(authControllerProvider).asData?.value.identity?.role;
    if (role != AppRole.owner ||
        guard.busy ||
        (guard.dirty && !discardConfirmed)) {
      return;
    }
    final shops = ref.read(shopContextProvider).asData?.value?.shops;
    if (shops != null && id != state && shops.any((shop) => shop.id == id)) {
      state = id;
      ref.read(salonSwitchRevisionProvider.notifier).advance();
    }
  }
}
