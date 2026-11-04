import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/role_policy.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_gate_screen.dart';
import '../../features/auth/presentation/role_landing_screens.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/dashboard_detail_screens.dart';
import '../../features/offers/presentation/offers_screen.dart';
import '../../features/offers/presentation/offer_details_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/menu/presentation/menu_controller.dart';
import '../../features/menu/presentation/menu_gate_screen.dart';
import '../../features/menu/presentation/no_access_screen.dart';
import '../../features/menu/presentation/mobile_menu_registry.dart';
import '../../features/queue/presentation/queue_controller.dart';
import '../../features/queue/presentation/queue_screen.dart';
import '../../features/queue/presentation/new_booking_screen.dart';
import '../../features/queue/presentation/booking_details_screen.dart';
import '../../features/shop_context/domain/shop_context.dart';
import '../../features/shop_context/presentation/shop_context_controller.dart';
import '../../features/shop_context/presentation/selected_shop_provider.dart';
import '../../features/shop_context/presentation/shop_context_gate_screen.dart';
import '../../features/upsell/presentation/web_feature_screen.dart';
import '../../features/services/presentation/services_screen.dart';
import '../../features/shop_users/presentation/shop_users_screen.dart';
import '../../features/shop_settings/presentation/shop_settings_screen.dart';
import 'menu_route_policy.dart';
import '../../features/menu/presentation/scope_revision_provider.dart';
import '../../features/shop_context/presentation/salon_selection_controller.dart';

/// Stable router. Redirects protect both declarative and imperative navigation.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  final navigator = GlobalKey<NavigatorState>();
  Uri? requested;
  var disposed = false;
  var resetRevision = 0;
  String destination() => sessionDestination(
    ref.read(authControllerProvider),
    ref.read(shopContextProvider),
    menu: ref.read(menuControllerProvider),
    selectedShop: ref.read(selectedShopProvider),
  );
  final router = GoRouter(
    navigatorKey: navigator,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) {
      final target = destination();
      final menu = ref.read(menuControllerProvider).asData?.value;
      if (target == '/login' || target == '/unsupported') requested = null;
      if (target == '/' || target == '/shop' || target == '/menu') {
        if (MobileMenuRegistry.tiles.any(
              (tile) => tile.route == state.uri.path,
            ) ||
            state.uri.path.startsWith('/web/offers/') ||
            state.uri.path.startsWith('/dashboard/') ||
            state.uri.path.startsWith('/queue/') ||
            state.uri.path.startsWith('/shop-settings/') ||
            state.uri.path == '/home') {
          requested = state.uri;
        }
        return state.uri.path == target ? null : target;
      }
      if (target == '/login' || target == '/unsupported' || menu == null) {
        return state.uri.path == target ? null : target;
      }
      if (state.uri.path == '/queue/new' &&
          !ref.read(canCreateWalkInProvider)) {
        requested = null;
        return '/queue';
      }
      final saved = requested;
      if (saved != null &&
          MenuRoutePolicy.redirect(saved, menu.projection) == null) {
        if (saved == state.uri) return null;
        // Concurrent refresh parses may still carry the previous gate URI.
        // Retain the target across those; a new feature navigation clears it.
        if (const {'/', '/login', '/shop', '/menu'}.contains(state.uri.path)) {
          return saved.toString();
        }
      }
      requested = null;
      return MenuRoutePolicy.redirect(state.uri, menu.projection);
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SessionGateScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/shop', builder: (_, _) => const ShopContextGateScreen()),
      GoRoute(path: '/menu', builder: (_, _) => const MenuGateScreen()),
      GoRoute(path: '/no-access', builder: (_, _) => const NoAccessScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/scan', builder: (_, _) => const MenuGateScreen()),
      for (final tile in MobileMenuRegistry.tiles)
        GoRoute(
          path: tile.route,
          routes: [
            if (tile.keys.contains('shop-setup'))
              for (final child in ShopSetupRegistry.children)
                GoRoute(
                  path: child.key,
                  builder: (_, _) =>
                      ShopSettingInformationScreen(destination: child),
                ),
            if (tile.tabs.isNotEmpty)
              GoRoute(path: 'new', builder: (_, _) => const NewBookingScreen()),
            if (tile.tabs.isNotEmpty)
              GoRoute(
                path: ':bookingId',
                builder: (_, state) => BookingDetailsScreen(
                  bookingId: state.pathParameters['bookingId'] ?? '',
                ),
              ),
            if (tile.keys.contains('shop-offers-2'))
              GoRoute(
                path: ':offerId',
                builder: (_, state) => OfferDetailsScreen(
                  offerId:
                      int.tryParse(state.pathParameters['offerId'] ?? '') ?? 0,
                ),
              ),
            if (tile.keys.contains('shopdashboard')) ...[
              GoRoute(
                path: 'services',
                builder: (_, _) => const DashboardServicesScreen(),
              ),
              GoRoute(
                path: 'staff',
                builder: (_, _) => const DashboardStaffScreen(),
                routes: [
                  GoRoute(
                    path: ':staffIndex',
                    builder: (_, state) => DashboardStaffDetailScreen(
                      staffIndex:
                          int.tryParse(
                            state.pathParameters['staffIndex'] ?? '',
                          ) ??
                          -1,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'low-stock',
                builder: (_, _) => const DashboardLowStockScreen(),
              ),
            ],
          ],
          builder: (_, state) {
            if (tile.keys.contains('shop-services-list')) {
              return const ServicesScreen();
            }
            if (tile.keys.contains('users-shop')) {
              return const ShopUsersScreen();
            }
            if (tile.keys.contains('shop-setup')) {
              return const ShopSettingsScreen();
            }
            if (tile.kind == TileKind.webOnly) {
              return WebFeatureScreen(tile: tile);
            }
            if (tile.keys.contains('shop-offers-2')) {
              return const OffersScreen();
            }
            if (tile.tabs.isNotEmpty) {
              return QueueScreen(
                requestedTab: state.uri.queryParameters['tab'],
              );
            }
            return const DashboardScreen();
          },
        ),
      for (final entry in roleLandingBuilders.entries)
        GoRoute(path: entry.key, builder: (context, _) => entry.value(context)),
    ],
    errorBuilder: (_, _) => const MenuGateScreen(),
  );
  void resetStack() {
    requested = null;
    final revision = ++resetRevision;
    scheduleMicrotask(() {
      if (disposed || revision != resetRevision) return;
      // A gate redirect may have captured the old feature since scheduling.
      requested = null;
      // go() replaces GoRouter's entire match list. Dialogs are pageless and
      // must also be removed, even when the visible feature is still permitted.
      navigator.currentState?.popUntil((route) => route.settings is Page);
      ref.invalidate(queueItemsProvider);
      router.go(destination());
    });
  }

  ref.listen(authControllerProvider, (previous, next) {
    if (previous?.asData?.value.identity != null &&
        (next.isLoading ||
            next.hasError ||
            next.asData?.value.identity == null ||
            previous?.asData?.value.ownership !=
                next.asData?.value.ownership)) {
      resetStack();
    }
    refresh.changed();
  });
  ref.listen(menuScopeProvider, (previous, next) {
    if (previous != null && previous != next) resetStack();
    refresh.changed();
  });
  ref.listen(salonSwitchRevisionProvider, (previous, next) {
    if (previous != null && previous != next) resetStack();
    refresh.changed();
  });
  ref.listen(shopContextProvider, (_, _) => refresh.changed());
  // Start account-scoped preference handling even for an automatic single salon.
  ref.listen(salonSelectionProvider, (_, _) => refresh.changed());
  ref.listen(menuControllerProvider, (previous, next) {
    final before = previous?.asData?.value?.snapshot;
    final after = next.asData?.value?.snapshot;
    if (before != null &&
        (next.hasError ||
            after == null ||
            before.scope != after.scope ||
            before.keys.any((key) => !after.keys.contains(key)) ||
            before.shopSetupChildren.any(
              (key) => !after.shopSetupChildren.contains(key),
            ))) {
      resetStack();
    }
    refresh.changed();
  });
  ref.onDispose(() {
    disposed = true;
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Gate precedence is auth, unsupported account, shop, menu, then projection.
String sessionDestination(
  AsyncValue<AuthView> auth,
  AsyncValue<ShopContext?> shop, {
  AsyncValue<MenuView?>? menu,
  Shop? selectedShop,
}) {
  if (auth.isLoading || auth.hasError || auth.asData?.value.locked == true) {
    return '/';
  }
  final identity = auth.asData?.value.identity;
  if (identity == null) return '/login';
  if (!RolePolicy.supports(identity.role)) return '/unsupported';
  if (shop.isLoading ||
      shop.hasError ||
      shop.asData?.value == null ||
      shop.asData?.value?.shops.isEmpty == true) {
    return '/shop';
  }
  final snapshot = menu?.asData?.value;
  if (menu == null ||
      menu.isLoading ||
      menu.hasError ||
      snapshot == null ||
      (selectedShop != null &&
          snapshot.snapshot.scope.shopId != selectedShop.id) ||
      snapshot.snapshot.scope.userId != identity.userId ||
      snapshot.snapshot.scope.subject != identity.subject) {
    return '/menu';
  }
  return snapshot.projection.landing;
}

class _RouterRefresh extends ChangeNotifier {
  void changed() => notifyListeners();
}
