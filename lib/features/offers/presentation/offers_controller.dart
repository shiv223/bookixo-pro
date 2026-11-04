import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/domain/menu_snapshot.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../shop_context/domain/shop_context.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../data/mock_offers_repository.dart';
import '../data/offers_repository_impl.dart';
import '../domain/offer.dart';
import '../domain/offer_schedule.dart';
import '../domain/offers_repository.dart';

final offersRepositoryProvider = Provider<OffersRepository>(
  (ref) => ref.watch(configProvider).demo
      ? MockOffersRepository()
      : OffersRepositoryImpl(ref.watch(protectedClientProvider)),
);

typedef OffersScope = ({MenuScope scope, int ownership, Shop shop});

/// Exact menu permission, validated selection and explicit login ownership.
final offersScopeProvider = Provider<OffersScope?>((ref) {
  final scope = ref.watch(menuScopeProvider);
  final shop = ref.watch(selectedShopProvider);
  final ownership = ref.watch(
    authControllerProvider.select((auth) => auth.asData?.value.ownership),
  );
  final menu = ref.watch(menuControllerProvider).asData?.value?.snapshot;
  if (scope == null ||
      shop == null ||
      ownership == null ||
      menu == null ||
      menu.scope != scope ||
      !menu.keys.contains('shop-offers-2')) {
    return null;
  }
  return (scope: scope, ownership: ownership, shop: shop);
});

enum OffersResource { offers, targets, rules }

/// List-only raw rule activity; never authorizes voucher export.
enum OfferListStatus { active, inactive, noRules, unavailable }

/// Failure is independent of loaded records, never a success-shaped fallback.
class ResourceState<T> {
  ResourceState({
    List<T> items = const [],
    this.page = -1,
    this.last = false,
    this.loading = false,
    this.failure,
    this.capped = false,
  }) : items = List.unmodifiable(items);
  final List<T> items;
  final int page;
  final bool last;
  final bool loading;
  final AppFailure? failure;
  final bool capped;
  bool get complete => last && !loading && failure == null && !capped;
  ResourceState<T> busy() =>
      ResourceState(items: items, page: page, last: false, loading: true);
}

class OffersView {
  OffersView({
    ResourceState<Offer>? offers,
    ResourceState<OfferTarget>? targets,
    ResourceState<ScheduleRule>? rules,
    this.scheduleRevision = 0,
  }) : offers = offers ?? ResourceState<Offer>(loading: true),
       targets = targets ?? ResourceState<OfferTarget>(loading: true),
       rules = rules ?? ResourceState<ScheduleRule>(loading: true);
  final ResourceState<Offer> offers;
  final ResourceState<OfferTarget> targets;
  final ResourceState<ScheduleRule> rules;
  final int scheduleRevision;
  bool get busy => offers.loading || targets.loading || rules.loading;
  Map<int, Offer> get byId => {
    for (final offer in offers.items) offer.id: offer,
  };
  Map<int, List<OfferTarget>> get targetsByOffer {
    final map = <int, List<OfferTarget>>{};
    for (final target in targets.items) {
      map.putIfAbsent(target.offerId, () => []).add(target);
    }
    return map;
  }

  Map<int, List<ScheduleRule>> get rulesByOffer {
    final map = <int, List<ScheduleRule>>{};
    for (final rule in rules.items) {
      map.putIfAbsent(rule.offerId, () => []).add(rule);
    }
    return map;
  }

  ScheduleSummary schedule(int id) =>
      OfferSchedules.merge(rulesByOffer[id] ?? []);

  // Each published view is immutable; build this index once rather than
  // regrouping every raw rule for each filter and sorting comparison.
  late final Map<int, OfferListStatus> _listStatuses = {
    for (final entry in rulesByOffer.entries)
      entry.key: entry.value.any((rule) => rule.isActive)
          ? OfferListStatus.active
          : OfferListStatus.inactive,
  };

  OfferListStatus listStatus(int id) {
    if (!rules.complete) return OfferListStatus.unavailable;
    return _listStatuses[id] ?? OfferListStatus.noRules;
  }

  bool canExport(int id, DateTime today) {
    final offer = byId[id];
    return offers.complete &&
        targets.complete &&
        rules.complete &&
        offer != null &&
        offer.validDates &&
        offer.knownDiscount &&
        offer.status(today) == OfferStatus.active &&
        !schedule(id).hasDiagnostics;
  }

  List<Offer> visible(OfferFilter filter) {
    final result = offers.items.where((offer) {
      final status = listStatus(offer.id);
      return filter == OfferFilter.all ||
          (filter == OfferFilter.active
              ? status == OfferListStatus.active
              : status == OfferListStatus.inactive);
    }).toList();
    result.sort((a, b) {
      final group = (listStatus(a.id) == OfferListStatus.active ? 0 : 1)
          .compareTo(listStatus(b.id) == OfferListStatus.active ? 0 : 1);
      return group == 0
          ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
          : group;
    });
    return result;
  }
}

final offersControllerProvider =
    AsyncNotifierProvider<OffersController, OffersView?>(
      OffersController.new,
      isAutoDispose: true,
      retry: (_, _) => null,
    );

/// Three parallel streams publish pages independently; epochs reject late work.
class OffersController extends AsyncNotifier<OffersView?> {
  int _epoch = 0;
  int _switchRevision = 0;
  OffersScope? _scope;
  final Map<OffersResource, Future<void>> _flights = {};
  @override
  OffersView? build() {
    _switchRevision = ref.watch(salonSwitchRevisionProvider);
    _scope = ref.watch(offersScopeProvider);
    final epoch = ++_epoch;
    _flights.clear();
    if (_scope == null) return null;
    Future.microtask(() {
      if (_current(epoch)) refresh();
    });
    return OffersView();
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(salonSwitchRevisionProvider) == _switchRevision &&
      _scope != null &&
      ref.read(offersScopeProvider) == _scope;

  Future<void> refresh() async {
    if (!_current(_epoch) || _flights.isNotEmpty) {
      return;
    }
    await Future.wait([
      for (final resource in OffersResource.values)
        retry(resource, restart: true),
    ]);
  }

  Future<void> retry(OffersResource resource, {bool restart = false}) {
    if (!_current(_epoch)) return Future.value();
    final existing = _flights[resource];
    if (existing != null) return existing;
    final epoch = _epoch;
    final scope = _scope;
    if (scope == null) return Future.value();
    final repository = ref.read(offersRepositoryProvider);
    final view = state.asData?.value;
    if (view == null) return Future.value();
    final complete = switch (resource) {
      OffersResource.offers => view.offers.complete,
      OffersResource.targets => view.targets.complete,
      OffersResource.rules => view.rules.complete,
    };
    if (!restart && complete) return Future.value();
    final Future<void> flight = switch (resource) {
      OffersResource.offers => _drain<Offer>(
        epoch,
        view.offers,
        restart,
        (page) => repository.offers(scope.scope, page),
        (value) => _publish(offers: value),
      ),
      OffersResource.targets => _drain<OfferTarget>(
        epoch,
        view.targets,
        restart,
        (page) => repository.targets(scope.scope, page),
        (value) => _publish(targets: value),
      ),
      OffersResource.rules => _drain<ScheduleRule>(
        epoch,
        view.rules,
        restart,
        (page) => repository.rules(scope.scope, page),
        (value) => _publish(rules: value),
      ),
    };
    _flights[resource] = flight;
    flight.whenComplete(() {
      if (_current(epoch) && identical(_flights[resource], flight)) {
        _flights.remove(resource);
      }
    });
    return flight;
  }

  void _publish({
    ResourceState<Offer>? offers,
    ResourceState<OfferTarget>? targets,
    ResourceState<ScheduleRule>? rules,
  }) {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData(
      OffersView(
        offers: offers ?? current.offers,
        targets: targets ?? current.targets,
        rules: rules ?? current.rules,
        scheduleRevision: current.scheduleRevision + (rules == null ? 0 : 1),
      ),
    );
  }

  Future<void> _drain<T>(
    int epoch,
    ResourceState<T> prior,
    bool restart,
    Future<ResourcePage<T>> Function(int) fetch,
    void Function(ResourceState<T>) publish,
  ) async {
    var items = prior.items.toList();
    var page = restart || prior.capped ? 0 : prior.page + 1;
    // A capped retry restarts at zero; failure must keep that retry cursor,
    // not the old page-nine cursor (which would strand the next Retry).
    var completedPage = page == 0 ? -1 : prior.page;
    var replace = page == 0;
    publish(prior.busy());
    try {
      for (; page < 10; page++) {
        final response = await fetch(page);
        if (!_current(epoch)) return;
        if (replace) {
          items = [];
          replace = false;
        }
        // Preserve raw rule sources for semantic normalization, dedupe other IDs.
        if (T == ScheduleRule) {
          final map = <int, T>{};
          for (final item in [...items, ...response.content]) {
            if (item is ScheduleRule) map.putIfAbsent(item.id, () => item);
          }
          items = map.values.toList();
          if (OfferSchedules.merge(items.whereType<ScheduleRule>())
              .hasDiagnostics) {
            ref.read(appLoggerProvider).offerScheduleDiagnostic();
          }
        } else {
          final map = <int, T>{};
          for (final item in [...items, ...response.content]) {
            final id = switch (item) {
              Offer o => o.id,
              OfferTarget t => t.id,
              _ => 0,
            };
            map[id] = item;
          }
          items = map.values.toList();
        }
        completedPage = page;
        final capped = page == 9 && !response.last;
        publish(
          ResourceState(
            items: items,
            page: page,
            last: response.last,
            loading: !response.last && !capped,
            capped: capped,
          ),
        );
        if (response.last || capped) return;
      }
    } on AppFailure catch (failure, stack) {
      if (!_current(epoch)) return;
      ref.read(appLoggerProvider).offersFailure(stack);
      publish(
        ResourceState(items: items, page: completedPage, failure: failure),
      );
    }
  }
}

final offerFilterProvider =
    NotifierProvider<OfferFilterController, OfferFilter>(
      OfferFilterController.new,
      isAutoDispose: true,
    );

class OfferFilterController extends Notifier<OfferFilter> {
  @override
  OfferFilter build() {
    ref.watch(salonSwitchRevisionProvider);
    ref.watch(offersScopeProvider);
    return OfferFilter.all;
  }

  void select(OfferFilter filter) => state = filter;
}

final offersTodayProvider = NotifierProvider<OffersToday, DateTime>(
  OffersToday.new,
  isAutoDispose: true,
);

/// One local-midnight timer and foreground recomputation, no network polling.
class OffersToday extends Notifier<DateTime> {
  void Function()? _cancel;
  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    final observer = _DateObserver(resume);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      _cancel?.call();
      WidgetsBinding.instance.removeObserver(observer);
    });
    final now = clock.now().toLocal();
    _schedule(now);
    return DateTime(now.year, now.month, now.day);
  }

  void _schedule(DateTime now) {
    _cancel?.call();
    _cancel = ref
        .read(clockProvider)
        .schedule(
          DateTime(now.year, now.month, now.day + 1).difference(now),
          resume,
        );
  }

  void resume() {
    if (!ref.mounted) return;
    final now = ref.read(clockProvider).now().toLocal();
    state = DateTime(now.year, now.month, now.day);
    _schedule(now);
  }
}

class _DateObserver extends WidgetsBindingObserver {
  _DateObserver(this.resume);
  final VoidCallback resume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resume();
  }
}
