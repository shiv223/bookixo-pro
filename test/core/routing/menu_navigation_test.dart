import 'dart:async';

import 'package:bookixo_pro/app.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/logging/app_logger.dart';
import 'package:bookixo_pro/core/routing/app_router.dart';
import 'package:bookixo_pro/core/routing/menu_route_policy.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/home/presentation/home_screen.dart';
import 'package:bookixo_pro/features/home/presentation/home_tile.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_projection.dart';
import 'package:bookixo_pro/features/menu/presentation/mobile_menu_registry.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_screen.dart';
import 'package:bookixo_pro/features/offers/presentation/offer_details_screen.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_screen.dart';
import 'package:bookixo_pro/features/shop_users/presentation/shop_users_controller.dart';
import 'package:bookixo_pro/features/shop_users/data/mock_shop_users_repository.dart';
import 'package:bookixo_pro/features/shop_settings/presentation/shop_settings_screen.dart';
import 'package:bookixo_pro/features/queue/data/mock_queue_repository.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/upsell/presentation/web_feature_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../features/menu/controller_test.dart' show FakeMenuRepository;
import '../../features/menu/projection_test.dart' show nineKeys;
import '../../features/home/logo_controller_test.dart' show FakeLogoRepository;
import '../../features/offers/controller_test.dart' show FakeOffersRepository;

class RecordingLogger extends AppLogger {
  int tiles = 0;
  int buttons = 0;
  @override
  void upsellTile() {
    tiles++;
  }

  @override
  void upsellButton() {
    buttons++;
  }
}

void main() {
  late ProviderContainer container;
  late FakeMenuRepository menu;
  late FakeAuthRepository auth;
  late FakeClock clock;
  late RecordingLogger logger;
  late FakeOffersRepository offers;
  setUp(() {
    clock = FakeClock();
    auth = FakeAuthRepository()..restored = sampleSession();
    logger = RecordingLogger();
    offers = FakeOffersRepository();
    final store = MenuCacheStore(MemoryBackend());
    menu = FakeMenuRepository(store, clock)..keys = nineKeys;
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(FakeShopRepository()),
        shopLogoRepositoryProvider.overrideWithValue(FakeLogoRepository()),
        offersRepositoryProvider.overrideWithValue(offers),
        queueRepositoryProvider.overrideWithValue(MockQueueRepository()),
        shopUsersRepositoryProvider.overrideWithValue(
          const MockShopUsersRepository(),
        ),
        clockProvider.overrideWithValue(clock),
        menuCacheStoreProvider.overrideWithValue(store),
        menuRepositoryProvider.overrideWithValue(menu),
        appLoggerProvider.overrideWithValue(logger),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String location() => container
      .read(routerProvider)
      .routeInformationProvider
      .value
      .uri
      .toString();
  Future<void> revoke(WidgetTester tester, Set<String> keys) async {
    menu.keys = keys;
    await container.read(menuControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();
  }

  test('all registry routes and tabs are exact guarded destinations', () {
    for (final tile in MobileMenuRegistry.tiles) {
      final allowed = MenuProjection({tile.keys.first});
      expect(MenuRoutePolicy.redirect(Uri.parse(tile.route), allowed), isNull);
      expect(
        MenuRoutePolicy.redirect(Uri.parse(tile.route), MenuProjection({})),
        '/no-access',
      );
    }
    final pending = MenuProjection({'bookings-pending'});
    expect(MenuRoutePolicy.redirect(Uri.parse('/queue/new'), pending), isNull);
    expect(
      MenuRoutePolicy.redirect(Uri.parse('/queue/new'), MenuProjection({})),
      '/no-access',
    );
    expect(
      MenuRoutePolicy.redirect(Uri.parse('/queue?tab=in-progress'), pending),
      '/queue?tab=pending',
    );
    expect(MenuRoutePolicy.redirect(Uri.parse('/scan'), pending), '/queue');
    expect(
      MenuRoutePolicy.redirect(Uri.parse('/customers'), pending),
      '/queue',
    );
  });
  testWidgets('every permitted direct feature remains navigable', (
    tester,
  ) async {
    await pump(tester);
    final router = container.read(routerProvider);
    for (final tile in MobileMenuRegistry.tiles) {
      router.go(tile.route);
      await tester.pumpAndSettle();
      expect(location(), tile.route);
      final header = tester.widget<AppInnerHeader>(find.byType(AppInnerHeader));
      expect(find.text('${header.title} · TS'), findsOneWidget);
      expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(find.byTooltip(AppStrings.logout), findsNothing);
      expect(find.text(AppStrings.logout), findsNothing);
      expect(tester.takeException(), isNull);
    }
    router.go('/queue/new');
    await tester.pumpAndSettle();
    expect(location(), '/queue/new');
    expect(find.text('New booking · TS'), findsOneWidget);
    router.go('/scan');
    await tester.pumpAndSettle();
    expect(location(), '/home');
  });

  testWidgets(
    'Setup children require immediate edges, including direct links and revocation',
    (tester) async {
      menu.keys = {
        'shop-setup',
        'workday',
        'shop-gst-settings',
        'shop-booking-qr',
        'shop-payment-config',
        'shop-logo',
        'unknown',
      };
      menu.setupChildren = {'workday', 'shop-logo', 'unknown'};
      await pump(tester);
      final router = container.read(routerProvider);
      router.go('/shop-settings');
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.workday), findsOneWidget);
      expect(find.text(AppStrings.shopLogo), findsOneWidget);
      expect(find.text(AppStrings.gstSettings), findsNothing);
      expect(find.text('unknown'), findsNothing);
      router.go('/shop-settings/shop-gst-settings');
      await tester.pumpAndSettle();
      expect(location(), '/home');
      router.go('/shop-settings/workday');
      await tester.pumpAndSettle();
      expect(find.byType(ShopSettingInformationScreen), findsOneWidget);
      expect(find.textContaining(AppStrings.availableOnWeb), findsOneWidget);
      expect(find.text('Workday · TS'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // Keep every flattened key but revoke the edge: stack must still be pruned.
      menu.setupChildren = {'shop-logo'};
      await container.read(menuControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(location(), '/home');
      expect(router.canPop(), isFalse);
      router.go('/shop-settings/workday');
      await tester.pumpAndSettle();
      expect(location(), '/home');
      router.go('/shop-settings/shop-logo');
      await tester.pumpAndSettle();
      expect(location(), '/shop-settings/shop-logo');
      await revoke(tester, {'shop-logo'});
      router.go('/shop-settings/shop-logo');
      await tester.pumpAndSettle();
      expect(location(), '/no-access');
    },
  );

  testWidgets(
    'Setup child deep link survives menu boot gate only when edge is granted',
    (tester) async {
      menu.keys = {'shop-setup', 'workday'};
      menu.setupChildren = {'workday'};
      container.read(routerProvider).go('/shop-settings/workday');
      await pump(tester);
      expect(location(), '/shop-settings/workday');
      menu.failure = const NetworkFailure();
      await container.read(menuControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(location(), '/shop-settings/workday');
      expect(
        container.read(menuControllerProvider).asData?.value?.stale,
        isTrue,
      );

      menu.failure = const ForbiddenFailure();
      await container.read(menuControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(location(), '/menu');
      expect(find.byType(ShopSettingInformationScreen), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'all five informational Setup children work at large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        menu.keys = {
          'shop-setup',
          for (final child in ShopSetupRegistry.children) child.key,
        };
        menu.setupChildren = {
          for (final child in ShopSetupRegistry.children) child.key,
        };
        await pump(tester);
        for (final child in ShopSetupRegistry.children) {
          container.read(routerProvider).go('/shop-settings');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text(child.title), 100);
          await tester.tap(find.text(child.title));
          await tester.pumpAndSettle();
          // Imperative pushes do not replace routeInformationProvider's URI.
          final information = tester.widget<ShopSettingInformationScreen>(
            find.byType(ShopSettingInformationScreen),
          );
          expect(information.destination.route, child.route);
          expect(find.text('${child.title} · TS'), findsOneWidget);
          expect(
            find.textContaining(AppStrings.availableOnWeb),
            findsOneWidget,
          );
          expect(find.byType(FilledButton), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('employee uses exact new menu keys with no extra role gate', (
    tester,
  ) async {
    auth.restored = sampleSession(groups: ['shop_employee']);
    menu.keys = {'shop-services-list', 'users-shop', 'shop-setup', 'workday'};
    menu.setupChildren = {'workday'};
    await pump(tester);
    for (final route in [
      '/services',
      '/shop-users',
      '/shop-settings',
      '/shop-settings/workday',
    ]) {
      container.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      expect(location(), route);
      expect(find.textContaining('₹'), findsNothing);
    }
  });

  testWidgets(
    'child headers retain titles and have no owner switch or logout',
    (tester) async {
      await pump(tester);
      for (final path in [
        '/queue/new',
        '/queue/sample-in-progress',
        '/dashboard/services',
        '/dashboard/staff',
        '/dashboard/staff/0',
        '/dashboard/low-stock',
        '/web/offers/1',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(location(), path);
        final header = tester.widget<AppInnerHeader>(
          find.byType(AppInnerHeader),
        );
        expect(find.text('${header.title} · TS'), findsOneWidget);
        expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
        expect(find.byIcon(Icons.storefront_outlined), findsNothing);
        expect(find.byTooltip(AppStrings.logout), findsNothing);
        expect(find.text(AppStrings.logout), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final failure in [false, true]) {
    testWidgets(
      'employee recovery preserves existing logout, failure $failure',
      (tester) async {
        auth.restored = sampleSession(groups: ['shop_employee']);
        menu.keys = {};
        if (failure) menu.failure = const NetworkFailure();
        await pump(tester);
        expect(location(), failure ? '/menu' : '/no-access');
        expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
        expect(find.byIcon(Icons.storefront_outlined), findsNothing);
        if (failure) {
          await tester.tap(find.text(AppStrings.logout));
        } else {
          await tester.tap(find.byTooltip(AppStrings.logout));
        }
        await tester.pumpAndSettle();
        expect(auth.logouts, 1);
        expect(location(), '/login');
      },
    );
  }
  testWidgets('all denied deep links and unknown routes go to safe landing', (
    tester,
  ) async {
    menu.keys = {'bookings-pending'};
    await pump(tester);
    for (final path in [
      '/home',
      '/dashboard',
      '/web/offers',
      '/web/credits-packages',
      '/web/membership',
      '/scan',
      '/customers',
      '/not-a-route',
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(location(), '/queue');
      expect(find.byType(QueueScreen), findsOneWidget);
    }
    expect(offers.reads, isEmpty);
  });
  for (final groups in [
    ['OWNER'],
    ['shop_employee'],
  ]) {
    testWidgets(
      'Offers native deep link permission for $groups and revocation',
      (tester) async {
        auth.restored = sampleSession(groups: groups);
        menu.keys = {'shop-offers-2', 'shopdashboard'};
        await pump(tester);
        container.read(routerProvider).go('/web/offers');
        await tester.pumpAndSettle();
        expect(find.byType(OffersScreen), findsOneWidget);
        expect(find.byType(WebFeatureScreen), findsNothing);
        expect(find.text(AppStrings.offersNotice), findsOneWidget);
        expect(find.text(AppStrings.webOnly), findsNothing);
        expect(find.textContaining('price'), findsNothing);
        expect(offers.reads, hasLength(3));
        expect(offers.reads.every((read) => read.$3 == 15), true);
        expect(find.byTooltip(AppStrings.refresh), findsNothing);
        container.read(routerProvider).go('/web/offers/1');
        await tester.pumpAndSettle();
        expect(find.byType(OfferDetailsScreen), findsOneWidget);
        expect(offers.reads, hasLength(3));
        await revoke(tester, {'shopdashboard'});
        expect(find.byType(OffersScreen), findsNothing);
        container.read(routerProvider).go('/web/offers/1');
        await tester.pumpAndSettle();
        expect(location(), '/home');
        expect(offers.reads, hasLength(3));
      },
    );
  }
  testWidgets('requested permitted deep link survives initial menu gate', (
    tester,
  ) async {
    menu.gate = Completer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pump();
    container.read(routerProvider).go('/web/offers');
    await tester.pump();
    expect(location(), '/menu');
    menu.gate?.complete(nineKeys);
    await tester.pumpAndSettle();
    expect(location(), '/web/offers');
  });
  testWidgets('owner cold failure shows Retry without switch or Logout', (
    tester,
  ) async {
    menu.failure = const NetworkFailure();
    await pump(tester);
    expect(location(), '/menu');
    expect(find.text(AppStrings.network), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
    expect(find.text(AppStrings.logout), findsNothing);
    expect(find.text(AppStrings.operations), findsNothing);
    menu.failure = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(location(), '/home');
  });
  testWidgets('successful empty and refresh recovery', (tester) async {
    menu.keys = {};
    await pump(tester);
    expect(location(), '/no-access');
    expect(find.text(AppStrings.noAccessBody), findsOneWidget);
    menu.keys = {'bookings-in-progress'};
    await tester.tap(find.byTooltip(AppStrings.refresh));
    await tester.pumpAndSettle();
    expect(location(), '/queue');
    expect(find.text(AppStrings.pending), findsNothing);
    expect(find.textContaining(AppStrings.inProgress), findsOneWidget);
  });
  testWidgets('revocation resets pushed stack and pageless dialog to zero', (
    tester,
  ) async {
    await pump(tester);
    final router = container.read(routerProvider);
    unawaited(router.push('/dashboard'));
    await tester.pumpAndSettle();
    unawaited(router.push('/web/offers'));
    await tester.pumpAndSettle();
    final context = tester.element(find.text(AppStrings.offersNotice));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Feature dialog')),
      ),
    );
    await tester.pumpAndSettle();
    await revoke(tester, {});
    expect(location(), '/no-access');
    expect(find.text('Feature dialog'), findsNothing);
    expect(router.canPop(), isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(location(), '/no-access');
  });
  testWidgets(
    'removed underlying screen is pruned even with permitted top screen',
    (tester) async {
      await pump(tester);
      final router = container.read(routerProvider);
      unawaited(router.push('/dashboard'));
      await tester.pumpAndSettle();
      unawaited(router.push('/web/offers'));
      await tester.pumpAndSettle();
      await revoke(tester, {'bookings-pending', 'shop-offers-2'});
      expect(router.canPop(), isFalse);
      expect(location(), '/home');
      router.go('/dashboard');
      await tester.pumpAndSettle();
      expect(location(), '/home');
    },
  );
  testWidgets('individual queue-tab revocation and tab deep link', (
    tester,
  ) async {
    menu.keys = {'bookings-pending', 'bookings-in-progress'};
    await pump(tester);
    container.read(routerProvider).go('/queue?tab=in-progress');
    await tester.pumpAndSettle();
    await revoke(tester, {'bookings-pending'});
    expect(find.text(AppStrings.pending), findsOneWidget);
    expect(find.text(AppStrings.inProgress), findsNothing);
    container.read(routerProvider).go('/queue?tab=in-progress');
    await tester.pumpAndSettle();
    expect(location(), '/queue?tab=pending');
  });
  testWidgets('logout dismisses dialog and prevents backstack resurrection', (
    tester,
  ) async {
    await pump(tester);
    final router = container.read(routerProvider);
    unawaited(router.push('/dashboard'));
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: tester.element(find.text('Dashboard · TS')),
        builder: (_) => const AlertDialog(content: Text('Old account dialog')),
      ),
    );
    await tester.pumpAndSettle();
    await container.read(authControllerProvider.notifier).logout();
    await tester.pumpAndSettle();
    expect(find.text('Old account dialog'), findsNothing);
    expect(location(), '/login');
    expect(router.canPop(), isFalse);
  });
  testWidgets('token rotation leaves feature route and menu unchanged', (
    tester,
  ) async {
    await pump(tester);
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    auth.refreshResult = Authenticated(sampleSession(salt: 'rotated'));
    await container
        .read(authControllerProvider.notifier)
        .ensureFresh(force: true);
    await tester.pumpAndSettle();
    expect(location(), '/dashboard');
    expect(menu.calls, 1);
  });
  testWidgets('forbidden refresh clears every feature route', (tester) async {
    await pump(tester);
    container.read(routerProvider).go('/dashboard');
    await tester.pumpAndSettle();
    menu.failure = const ForbiddenFailure();
    await container.read(menuControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(location(), '/menu');
    expect(find.text(AppStrings.forbidden), findsOneWidget);
    menu.failure = const NetworkFailure();
    await container.read(menuControllerProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(location(), '/menu');
  });
  for (final brightness in Brightness.values) {
    testWidgets('Home 320px large text $brightness scrolls without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pump(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text(AppStrings.creditsPackages),
        250,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.creditsPackages), findsOneWidget);
      expect(find.text('Add customers'), findsNothing);
      for (final button in find.byType(IconButton).evaluate()) {
        expect(
          tester.getSize(find.byWidget(button.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
    });
  }
  testWidgets('short Home list pulls to refresh and stale feedback appears', (
    tester,
  ) async {
    menu.keys = {'shopdashboard'};
    await pump(tester);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    menu.failure = const NetworkFailure();
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(menu.calls, 2);
    expect(find.text(AppStrings.staleMenu), findsOneWidget);
    expect(location(), '/home');
  });
  testWidgets('web tile and unavailable button log only allowlisted events', (
    tester,
  ) async {
    menu.keys = {'shop-credits-packages'};
    await pump(tester);
    await tester.tap(find.text(AppStrings.creditsPackages));
    await tester.pumpAndSettle();
    expect(find.byType(WebFeatureScreen), findsOneWidget);
    await tester.tap(find.text(AppStrings.unavailableWeb));
    await tester.pumpAndSettle();
    expect(logger.tiles, 1);
    expect(logger.buttons, 1);
    expect(find.text(AppStrings.unavailableWebBody), findsNWidgets(2));
  });
  testWidgets('app resume obeys 59/60 boundary after auth check', (
    tester,
  ) async {
    await pump(tester);
    clock.advance(const Duration(seconds: 59));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(menu.calls, 1);
    clock.advance(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(menu.calls, 2);
  });
  testWidgets('wide Home tiles use two columns and grow into large-text rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    menu.keys = {'shop-offers-2', 'shop-credits-packages', 'shop-memberships'};
    await pump(tester);
    Finder tile(String title) => find.byWidgetPredicate(
      (widget) => widget is HomeTile && widget.tile.title == title,
    );
    final offers = tester.getRect(tile(AppStrings.offers));
    final credits = tester.getRect(tile(AppStrings.creditsPackages));
    final membership = tester.getRect(tile(AppStrings.membership));
    expect(credits.top, offers.top);
    expect(credits.left, offers.right + 12);
    expect(credits.width, offers.width);
    expect(credits.height, offers.height);
    expect(membership.top, credits.bottom + 12);
    expect(membership.left, offers.left);
    expect(membership.width, offers.width + 12 + credits.width);
    expect(find.text(AppStrings.webOnly), findsNWidgets(2));
    expect(find.text('More on Bookixo web'), findsNothing);
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    final largeOffers = tester.getRect(tile(AppStrings.offers));
    final largeCredits = tester.getRect(tile(AppStrings.creditsPackages));
    final largeMembership = tester.getRect(tile(AppStrings.membership));
    expect(largeOffers.width, membership.width);
    expect(largeOffers.height, greaterThan(offers.height));
    expect(largeCredits.left, largeOffers.left);
    expect(largeCredits.width, largeOffers.width);
    expect(largeCredits.top, largeOffers.bottom + 12);
    expect(largeMembership.left, largeOffers.left);
    expect(largeMembership.width, largeOffers.width);
    expect(largeMembership.top, largeCredits.bottom + 12);
    expect(tester.takeException(), isNull);
  });
  for (final tile in MobileMenuRegistry.tiles) {
    testWidgets(
      '${tile.route} revocation dismisses dialog, prunes stack and blocks reentry',
      (tester) async {
        await pump(tester);
        final router = container.read(routerProvider);
        unawaited(router.push(tile.route));
        await tester.pumpAndSettle();
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(Scaffold).last),
            builder: (_) =>
                const AlertDialog(content: Text('Revoked feature dialog')),
          ),
        );
        await tester.pumpAndSettle();
        await revoke(tester, nineKeys.difference(tile.keys));
        expect(location(), '/home');
        expect(find.text('Revoked feature dialog'), findsNothing);
        expect(router.canPop(), isFalse);
        router.go(tile.route);
        await tester.pumpAndSettle();
        expect(location(), '/home');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(location(), '/home');
      },
    );
  }
  testWidgets('Pending revocation leaves only In progress', (tester) async {
    menu.keys = {'bookings-pending', 'bookings-in-progress'};
    await pump(tester);
    await revoke(tester, {'bookings-in-progress'});
    expect(find.text(AppStrings.pending), findsNothing);
    expect(find.textContaining(AppStrings.inProgress), findsOneWidget);
    container.read(routerProvider).go('/queue?tab=pending');
    await tester.pumpAndSettle();
    expect(location(), '/queue?tab=in-progress');
  });
}
