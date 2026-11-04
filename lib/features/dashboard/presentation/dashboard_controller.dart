import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../data/dashboard_repository_impl.dart';
import '../data/mock_dashboard_repository.dart';
import '../domain/dashboard_analytics.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => ref.watch(configProvider).demo
      ? const MockDashboardRepository()
      : DashboardRepositoryImpl(ref.watch(protectedClientProvider)),
);

typedef DashboardAccess = ({DashboardScope scope, Set<String> features});

/// Dashboard data is available only under the server-issued menu snapshot.
final dashboardAccessProvider = Provider<DashboardAccess?>((ref) {
  final menuScope = ref.watch(menuScopeProvider);
  final shop = ref.watch(selectedShopProvider);
  final ownership = ref.watch(
    authControllerProvider.select((auth) => auth.asData?.value.ownership),
  );
  final snapshot = ref.watch(menuControllerProvider).asData?.value?.snapshot;
  if (menuScope == null ||
      shop == null ||
      ownership == null ||
      snapshot == null ||
      snapshot.scope != menuScope ||
      snapshot.scope.shopId != shop.id ||
      !snapshot.keys.contains('shopdashboard')) {
    return null;
  }
  return (
    scope: DashboardScope(menu: menuScope, ownership: ownership),
    features: Set.unmodifiable(snapshot.keys),
  );
});

final dashboardRangeProvider =
    NotifierProvider<DashboardRangeController, DashboardRange>(
      DashboardRangeController.new,
    );

class DashboardRangeController extends Notifier<DashboardRange> {
  @override
  DashboardRange build() => DashboardRange.today;

  void select(DashboardRange range) => state = range;
}

class DashboardView {
  DashboardView({
    required this.scope,
    required this.range,
    required this.window,
    required this.previousWindow,
    required this.features,
    Map<DashboardResource, DashboardResourceState<Object>> resources = const {},
  }) : resources = Map.unmodifiable(resources);

  final DashboardScope scope;
  final DashboardRange range;
  final DateWindow window;
  final DateWindow previousWindow;
  final Set<String> features;
  final Map<DashboardResource, DashboardResourceState<Object>> resources;

  DashboardResourceState<Object> resource(DashboardResource key) =>
      resources[key] ?? const DashboardResourceState<Object>();

  List<T>? rows<T>(DashboardResource key) {
    final value = resource(key).value;
    return value is DashboardRows<T> ? value.rows : null;
  }

  DashboardView update(
    DashboardResource key,
    DashboardResourceState<Object> resource,
  ) => DashboardView(
    scope: scope,
    range: range,
    window: window,
    previousWindow: previousWindow,
    features: features,
    resources: {...resources, key: resource},
  );

  DashboardView updateMany(
    Map<DashboardResource, DashboardResourceState<Object>> values,
  ) => DashboardView(
    scope: scope,
    range: range,
    window: window,
    previousWindow: previousWindow,
    features: features,
    resources: {...resources, ...values},
  );
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardView?>(
      DashboardController.new,
      isAutoDispose: true,
      retry: (_, _) => null,
    );

/// Lazy per-resource loading with scoped epochs and retryable independent reads.
class DashboardController extends AsyncNotifier<DashboardView?> {
  int _epoch = 0;
  int _switchRevision = 0;
  DashboardAccess? _access;
  DashboardRange? _range;
  final Map<DashboardResource, Future<void>> _flights = {};

  @override
  DashboardView? build() {
    _switchRevision = ref.watch(salonSwitchRevisionProvider);
    _access = ref.watch(dashboardAccessProvider);
    _range = ref.watch(dashboardRangeProvider);
    final epoch = ++_epoch;
    _flights.clear();
    final access = _access;
    final range = _range;
    if (access == null || range == null) return null;
    final window = DashboardAnalytics.currentWindow(range, DateTime.now());
    final view = DashboardView(
      scope: access.scope,
      range: range,
      window: window,
      previousWindow: DashboardAnalytics.previousWindow(window),
      features: access.features,
    );
    Future.microtask(() {
      if (_current(epoch)) loadTop();
    });
    return view;
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(salonSwitchRevisionProvider) == _switchRevision &&
      _access != null &&
      ref.read(dashboardAccessProvider) == _access &&
      ref.read(dashboardRangeProvider) == _range;

  Future<void> loadTop({bool force = false}) async {
    await Future.wait([
      load(DashboardResource.bookings, force: force),
      load(DashboardResource.orders, force: force),
      load(DashboardResource.previousBookings, force: force),
      load(DashboardResource.previousOrders, force: force),
      load(DashboardResource.staffServices, force: force),
    ]);
  }

  Future<void> refresh() async {
    if (!_current(_epoch)) return;
    await loadTop(force: true);
    final loaded =
        state.asData?.value?.resources.keys
            .where(
              (resource) => !{
                DashboardResource.bookings,
                DashboardResource.orders,
                DashboardResource.previousBookings,
                DashboardResource.previousOrders,
                DashboardResource.staffServices,
              }.contains(resource),
            )
            .toList() ??
        const <DashboardResource>[];
    await Future.wait([
      for (final resource in loaded) load(resource, force: true),
    ]);
  }

  Future<void> retry(DashboardResource resource) => load(resource, force: true);

  Future<void> load(DashboardResource resource, {bool force = false}) {
    final epoch = _epoch;
    final access = _access;
    final view = state.asData?.value;
    if (access == null ||
        view == null ||
        !_current(epoch) ||
        !_featureAllows(access, resource)) {
      return Future.value();
    }
    final existing = _flights[resource];
    if (existing != null) return existing;
    final previous = view.resource(resource);
    if (!force && previous.value != null && previous.failure == null) {
      return Future.value();
    }
    final flight = _perform(resource, access, view, epoch, previous);
    _flights[resource] = flight;
    flight.whenComplete(() {
      if (_current(epoch) && identical(_flights[resource], flight)) {
        _flights.remove(resource);
      }
    });
    return flight;
  }

  bool _featureAllows(DashboardAccess access, DashboardResource resource) =>
      switch (resource) {
        DashboardResource.walletPurchases => access.features.contains(
          'shop-credits-packages',
        ),
        DashboardResource.membershipSales => access.features.contains(
          'shop-memberships',
        ),
        _ => true,
      };

  Future<void> _perform(
    DashboardResource resource,
    DashboardAccess access,
    DashboardView view,
    int epoch,
    DashboardResourceState<Object> previous,
  ) async {
    _publish(
      resource,
      DashboardResourceState<Object>(value: previous.value, loading: true),
    );
    final repository = ref.read(dashboardRepositoryProvider);
    final shopId = access.scope.menu.shopId;
    final currentWindow = view.window;
    final previousWindow = view.previousWindow;
    try {
      final Object result = switch (resource) {
        DashboardResource.bookings => await repository.bookings(
          shopId,
          currentWindow,
        ),
        DashboardResource.previousBookings => await repository.bookings(
          shopId,
          previousWindow,
        ),
        DashboardResource.orders => await repository.orders(
          shopId,
          currentWindow,
        ),
        DashboardResource.previousOrders => await repository.orders(
          shopId,
          previousWindow,
        ),
        DashboardResource.staffServices => await repository.staffServices(
          shopId,
          currentWindow,
        ),
        DashboardResource.statuses => await repository.statuses(
          shopId,
          currentWindow,
        ),
        DashboardResource.inventory => await repository.inventory(shopId),
        DashboardResource.walletPurchases => await repository.walletPurchases(
          shopId,
          currentWindow,
        ),
        DashboardResource.membershipSales => await repository.membershipSales(
          shopId,
          currentWindow,
        ),
      };
      if (_current(epoch)) {
        _publish(resource, DashboardResourceState<Object>(value: result));
      }
    } on AppFailure catch (failure, stack) {
      if (_current(epoch)) {
        ref.read(appLoggerProvider).dashboardFailure(stack);
        _publish(
          resource,
          DashboardResourceState<Object>(
            value: previous.value,
            failure: failure,
          ),
        );
      }
    }
  }

  void _publish(
    DashboardResource resource,
    DashboardResourceState<Object> value,
  ) {
    final view = state.asData?.value;
    if (view != null) state = AsyncData(view.update(resource, value));
  }
}
