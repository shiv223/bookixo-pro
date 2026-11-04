import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/offers/data/offers_dto.dart';
import 'package:bookixo_pro/features/offers/data/offers_repository_impl.dart';
import 'package:bookixo_pro/features/offers/domain/offer.dart';
import 'package:bookixo_pro/features/offers/domain/offers_repository.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'contract_test.dart';

const firstScope = (
  scope: MenuScope('5', 'subject', 15),
  ownership: 1,
  shop: Shop(15, 'Fuzion'),
);
final testScopeProvider = NotifierProvider<TestScopeController, OffersScope?>(
  TestScopeController.new,
);

class TestScopeController extends Notifier<OffersScope?> {
  @override
  OffersScope? build() => firstScope;
  void replace(OffersScope? scope) => state = scope;
}

ResourcePage<T> samplePage<T>(List<T> items, int page, {bool last = true}) =>
    ResourcePage(items, page, 100, items.length, last ? page + 1 : 10, last);

class FakeOffersRepository implements OffersRepository {
  final reads = <(String, int, int)>[];
  final offerGates = <int, Completer<ResourcePage<Offer>>>{};
  final targetGates = <int, Completer<ResourcePage<OfferTarget>>>{};
  final ruleGates = <int, Completer<ResourcePage<ScheduleRule>>>{};
  int offerPages = 1;
  int targetPages = 1;
  int rulePages = 1;
  int? offerFailurePage;
  AppFailure? targetsFailure;
  AppFailure? rulesFailure;
  List<Offer> offerItems = [OffersDto.offer(offerJson())];
  List<OfferTarget> targetItems = [OffersDto.target(targetJson())];
  List<ScheduleRule> ruleItems = [OffersDto.rule(ruleJson())];
  @override
  Future<ResourcePage<Offer>> offers(MenuScope scope, int page) async {
    reads.add(('offers', page, scope.shopId));
    if (offerFailurePage == page) throw const NetworkFailure();
    return offerGates[page]?.future ??
        samplePage(
          page == 0 ? offerItems : [OffersDto.offer(offerJson(id: page + 1))],
          page,
          last: page == offerPages - 1,
        );
  }

  @override
  Future<ResourcePage<OfferTarget>> targets(MenuScope scope, int page) async {
    reads.add(('targets', page, scope.shopId));
    final error = targetsFailure;
    if (error != null) throw error;
    return targetGates[page]?.future ??
        samplePage(targetItems, page, last: page == targetPages - 1);
  }

  @override
  Future<ResourcePage<ScheduleRule>> rules(MenuScope scope, int page) async {
    reads.add(('rules', page, scope.shopId));
    final error = rulesFailure;
    if (error != null) throw error;
    return ruleGates[page]?.future ??
        samplePage(ruleItems, page, last: page == rulePages - 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeOffersRepository repo;
  late ProviderContainer container;
  setUp(() {
    repo = FakeOffersRepository();
    container = ProviderContainer(
      overrides: [
        offersScopeProvider.overrideWith((ref) => ref.watch(testScopeProvider)),
        offersRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() => container.dispose());
  OffersView? view() => container.read(offersControllerProvider).asData?.value;
  OffersController controller() =>
      container.read(offersControllerProvider.notifier);
  void boot() => container.listen(offersControllerProvider, (_, _) {});
  test('rapid A B A switch rejects late offers in the same scope', () async {
    final gate = Completer<ResourcePage<Offer>>();
    repo.offerGates[0] = gate;
    boot();
    await flush();
    repo.offerGates.clear();
    final revision = container.read(salonSwitchRevisionProvider.notifier);
    revision.advance();
    revision.advance();
    await flush();
    gate.complete(samplePage([OffersDto.offer(offerJson(id: 999))], 0));
    await flush();
    expect(view()?.offers.items.map((offer) => offer.id), [1]);
  });
  test(
    'identity duplicates across pages deduplicate but semantic IDs survive',
    () async {
      repo.rulePages = 2;
      repo.ruleItems.add(OffersDto.rule(ruleJson(id: 2)));
      boot();
      await flush();
      expect(view()?.rules.items.map((rule) => rule.id), [1, 2]);
      expect(view()?.schedule(1).schedules, hasLength(1));
    },
  );
  test('starts all three concurrently and publishes first offers before other streams', () async {
    repo.offerGates[0] = Completer();
    repo.offerGates[1] = Completer();
    repo.targetGates[0] = Completer();
    repo.ruleGates[0] = Completer();
    boot();
    await flush();
    expect(repo.reads.map((r) => r.$1), ['offers', 'targets', 'rules']);
    repo.offerGates[0]?.complete(
      samplePage([OffersDto.offer(offerJson())], 0, last: false),
    );
    await flush();
    expect(view()?.offers.items, hasLength(1));
    expect(view()?.targets.loading, true);
    expect(view()?.listStatus(1), OfferListStatus.unavailable);
    expect(view()?.visible(OfferFilter.active), isEmpty);
    expect(repo.reads.where((r) => r.$1 == 'offers').map((r) => r.$2), [0, 1]);
    repo.offerGates[1]?.complete(
      samplePage([OffersDto.offer(offerJson(id: 2))], 1),
    );
    repo.targetGates[0]?.complete(samplePage([], 0));
    repo.ruleGates[0]?.complete(samplePage([], 0));
    await flush();
    expect(view()?.offers.items, hasLength(2));
  });
  test('partial offer failure retains records; resource Retry resumes failed page only', () async {
    repo.offerPages = 3;
    repo.offerFailurePage = 1;
    repo.targetsFailure = const ForbiddenFailure();
    boot();
    await flush();
    expect(view()?.offers.items, hasLength(1));
    expect(view()?.offers.failure, isA<NetworkFailure>());
    expect(view()?.targets.complete, false);
    expect(view()?.targets.failure, isA<ForbiddenFailure>());
    repo.offerFailurePage = null;
    await controller().retry(OffersResource.offers);
    expect(view()?.offers.items, hasLength(3));
    expect(repo.reads.where((r) => r.$1 == 'offers').map((r) => r.$2), [
      0,
      1,
      1,
      2,
    ]);
    expect(repo.reads.where((r) => r.$1 == 'targets'), hasLength(1));
    expect(view()?.targets.failure, isA<ForbiddenFailure>());
    repo.targetsFailure = null;
    await controller().retry(OffersResource.targets);
    expect(view()?.canExport(1, DateTime(2026, 10, 8)), true);
  });
  test(
    'short/empty page is not last; three independent caps remain incomplete',
    () async {
      repo.offerPages = 11;
      repo.targetPages = 3;
      repo.rulePages = 12;
      boot();
      await flush();
      expect(view()?.offers.items, hasLength(10));
      expect(view()?.offers.capped, true);
      expect(view()?.targets.complete, true);
      expect(view()?.rules.capped, true);
      expect(view()?.listStatus(1), OfferListStatus.unavailable);
      expect(view()?.visible(OfferFilter.active), isEmpty);
      expect(view()?.visible(OfferFilter.inactive), isEmpty);
      expect(
        repo.reads.where((r) => r.$1 == 'offers').map((r) => r.$2),
        List.generate(10, (i) => i),
      );
      expect(repo.reads.where((r) => r.$1 == 'targets'), hasLength(3));
      expect(view()?.canExport(1, DateTime(2026, 10, 8)), false);
      repo.offerPages = 1;
      await controller().retry(OffersResource.offers);
      expect(view()?.offers.items, hasLength(1));
      expect(view()?.offers.complete, true);
    },
  );
  test('real repository drains every endpoint with shopId/page/size, retains failure', () async {
    container.dispose();
    final adapter = StubAdapter((request) {
      final page = request.queryParameters['page'] as int;
      final path = request.path;
      if (path == 'api/offer-targets' && page == 1) {
        return (status: 500, body: null);
      }
      return (
        status: 200,
        body: pageJson(
          [
            if (path == 'api/shop-offers') offerJson(id: page + 1),
            if (path == 'api/offer-targets') targetJson(),
            if (path == 'api/offer-schedule-rules') ruleJson(),
          ],
          page: page,
          last: path == 'api/shop-offers' && page == 1,
        ),
      );
    });
    container = ProviderContainer(
      overrides: [
        offersScopeProvider.overrideWithValue(firstScope),
        offersRepositoryProvider.overrideWithValue(
          OffersRepositoryImpl(stubClient(adapter)),
        ),
      ],
    );
    container.listen(offersControllerProvider, (_, _) {});
    await flush();
    await Future.wait([
      for (final resource in OffersResource.values)
        controller().retry(resource),
    ]);
    expect(view()?.offers.items, hasLength(2));
    expect(view()?.targets.items, hasLength(1));
    expect(view()?.targets.failure, isA<ServerFailure>());
    expect(view()?.rules.capped, true);
    for (final request in adapter.requests) {
      expect(request.method, 'GET');
      expect(request.queryParameters['size'], 100);
      expect(request.queryParameters['shopId'], 15);
      expect(request.queryParameters['page'], lessThan(10));
    }
  });
  test(
    'refresh failure never empties loaded offers; refresh single-flight',
    () async {
      boot();
      await flush();
      repo.offerGates[0] = Completer();
      final flight = controller().refresh();
      final count = repo.reads.length;
      await controller().refresh();
      expect(repo.reads.length, count);
      repo.offerGates[0]?.completeError(
        const NetworkFailure(),
        StackTrace.empty,
      );
      await flight;
      expect(view()?.offers.items, hasLength(1));
      expect(view()?.offers.failure, isA<NetworkFailure>());
    },
  );
  for (final replacement in <OffersScope?>[
    null,
    (
      scope: MenuScope('5', 'subject', 16),
      ownership: 1,
      shop: Shop(16, 'Other'),
    ),
    (
      scope: MenuScope('6', 'other', 15),
      ownership: 2,
      shop: Shop(15, 'Fuzion'),
    ),
    (
      scope: MenuScope('5', 'subject', 15),
      ownership: 2,
      shop: Shop(15, 'Fuzion'),
    ),
  ]) {
    test('scope replacement $replacement rejects late results', () async {
      final oldOffers = Completer<ResourcePage<Offer>>();
      final oldTargets = Completer<ResourcePage<OfferTarget>>();
      repo.offerGates[0] = oldOffers;
      repo.targetGates[0] = oldTargets;
      boot();
      await flush();
      final newOffers = Completer<ResourcePage<Offer>>();
      final newTargets = Completer<ResourcePage<OfferTarget>>();
      repo.offerGates[0] = newOffers;
      repo.targetGates[0] = newTargets;
      container.read(testScopeProvider.notifier).replace(replacement);
      await flush();
      oldOffers.complete(samplePage([OffersDto.offer(offerJson(id: 99))], 0));
      oldTargets.complete(samplePage([], 0));
      await flush();
      if (replacement == null) {
        expect(view(), isNull);
      } else {
        expect(view()?.offers.items, isEmpty);
        expect(view()?.offers.loading, true);
        newOffers.complete(samplePage([OffersDto.offer(offerJson(id: 4))], 0));
        newTargets.complete(samplePage([], 0));
        await flush();
        expect(view()?.offers.items.map((offer) => offer.id), [4]);
        expect(repo.reads.where((r) => r.$1 == 'offers'), hasLength(2));
      }
    });
  }
  test('unpermitted scope issues no reads', () async {
    container.read(testScopeProvider.notifier).replace(null);
    boot();
    await flush();
    expect(view(), isNull);
    expect(repo.reads, isEmpty);
  });
  test('empty first page with last false continues, while repeat completed Retry is a no-op', () async {
    repo.offerItems = [];
    repo.offerPages = 2;
    boot();
    await flush();
    expect(view()?.offers.items.map((offer) => offer.id), [2]);
    final reads = repo.reads.length;
    await controller().retry(OffersResource.offers);
    expect(repo.reads.length, reads);
  });
  test('failed capped restart retains offers and next Retry still starts at page zero', () async {
    repo.offerPages = 11;
    boot();
    await flush();
    expect(view()?.offers.capped, true);
    repo.offerFailurePage = 0;
    await controller().retry(OffersResource.offers);
    expect(view()?.offers.items, hasLength(10));
    expect(view()?.offers.failure, isA<NetworkFailure>());
    expect(view()?.offers.page, -1);
    repo.offerFailurePage = null;
    repo.offerPages = 1;
    await controller().retry(OffersResource.offers);
    expect(view()?.offers.complete, true);
    expect(view()?.offers.items, hasLength(1));
    expect(
      repo.reads
          .where((read) => read.$1 == 'offers')
          .map((read) => read.$2)
          .toList()
          .sublist(10),
      [0, 0],
    );
  });
  test(
    'clock updates at local midnight and on resume without repository polling',
    () async {
      final clock = FakeClock(DateTime(2026, 10, 8, 23, 59, 59));
      final dates = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(clock)],
      );
      addTearDown(dates.dispose);
      dates.listen(offersTodayProvider, (_, _) {});
      expect(dates.read(offersTodayProvider), DateTime(2026, 10, 8));
      clock.advance(const Duration(seconds: 1));
      expect(dates.read(offersTodayProvider), DateTime(2026, 10, 9));
      clock.time = DateTime(2026, 10, 12, 10);
      dates.read(offersTodayProvider.notifier).resume();
      expect(dates.read(offersTodayProvider), DateTime(2026, 10, 12));
      expect(clock.scheduled.where((task) => !task.cancelled[0]), hasLength(1));
      expect(repo.reads, isEmpty);
    },
  );
}
