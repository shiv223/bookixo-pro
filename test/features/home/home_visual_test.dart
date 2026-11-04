import 'dart:io';

import 'package:bookixo_pro/app.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/core/widgets/brand_background.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/home/presentation/home_screen.dart';
import 'package:bookixo_pro/features/home/presentation/home_tile.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/mobile_menu_registry.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/salon_preference_repository.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_selection_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../menu/controller_test.dart' show FakeMenuRepository;
import '../menu/projection_test.dart' show nineKeys;
import 'logo_controller_test.dart' show FakeLogoRepository, LogoLogger;
import '../offers/controller_test.dart' show FakeOffersRepository;

class TestSalonPreferences implements SalonPreferenceRepository {
  final values = <String, int>{};

  @override
  Future<int?> read(String account) async => values[account];

  @override
  Future<void> write(
    String account,
    int shopId,
    bool Function() isCurrent,
  ) async {
    if (isCurrent()) values[account] = shopId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Ahem's square glyphs distort the reference typography. Use the fonts
    // already shipped with the running Flutter SDK, not a new dependency.
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!File(
      '${sdk.path}/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    ).existsSync()) {
      final parent = sdk.parent;
      if (parent.path == sdk.path) {
        throw StateError('Flutter SDK material font fixture is unavailable');
      }
      sdk = parent;
    }
    final loader = FontLoader('Roboto');
    for (final face in ['regular', 'bold']) {
      final bytes = await File(
        '${sdk.path}/bin/cache/artifacts/material_fonts/roboto-$face.ttf',
      ).readAsBytes();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });
  late ProviderContainer container;
  late FakeLogoRepository logos;
  late LogoLogger logger;
  late FakeAuthRepository auth;
  late FakeShopRepository shops;
  late FakeMenuRepository menu;
  late TestSalonPreferences salonPreferences;
  setUp(() {
    final clock = FakeClock();
    final store = MenuCacheStore(MemoryBackend());
    logos = FakeLogoRepository();
    logger = LogoLogger();
    auth = FakeAuthRepository()..restored = sampleSession();
    shops = FakeShopRepository();
    menu = FakeMenuRepository(store, clock)..keys = nineKeys;
    salonPreferences = TestSalonPreferences();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(shops),
        salonPreferenceRepositoryProvider.overrideWithValue(salonPreferences),
        shopLogoRepositoryProvider.overrideWithValue(logos),
        offersRepositoryProvider.overrideWithValue(FakeOffersRepository()),
        appLoggerProvider.overrideWithValue(logger),
        clockProvider.overrideWithValue(clock),
        menuCacheStoreProvider.overrideWithValue(store),
        menuRepositoryProvider.overrideWithValue(menu),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String title) => find.byWidgetPredicate(
    (widget) => widget is HomeTile && widget.tile.title == title,
  );

  testWidgets(
    '390x780 hybrid Home keeps the branded header and responsive feature cards',
    (tester) async {
      await pump(tester, const Size(390, 780), 1);
      final header = tester.getRect(find.byType(HomeHeader));
      final operations = tester.getRect(tile(AppStrings.operations));
      final dashboard = tester.getRect(tile(AppStrings.homeDashboard));
      expect(header.height, closeTo(108, 2));
      expect(operations.left, 20);
      expect(operations.width, 350);
      expect(operations.top, closeTo(100, 2));
      expect(header.bottom - operations.top, 8);
      expect(operations.height, greaterThanOrEqualTo(AppTokens.target));
      expect(dashboard.top - operations.bottom, 12);
      expect(dashboard.width, 169);
      final icon = tester.getRect(find.byIcon(Icons.content_cut));
      final title = tester.getRect(find.text(AppStrings.operations));
      final subtitle = tester.getRect(find.text(AppStrings.operationsSubtitle));
      expect(icon.right + 12, title.left);
      expect(title.left, subtitle.left);
      expect(subtitle.top, greaterThan(title.top));
      expect(
        tester.widget<Text>(find.text(AppStrings.operations)).style?.fontSize,
        18,
      );
      expect(
        tester
            .widget<Text>(find.text(AppStrings.operationsSubtitle))
            .style
            ?.fontSize,
        13,
      );
      expect(find.text(AppStrings.welcomeBack), findsOneWidget);
      expect(find.textContaining('Test salon · Owner'), findsOneWidget);
      expect(
        tester.getSize(find.byType(HomeLogout)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byType(HomeTile), findsNWidgets(8));
      expect(find.text('Add customers'), findsNothing);
      expect(find.text(AppStrings.webOnly), findsNWidgets(2));
      expect(find.text(AppStrings.offersSubtitle), findsOneWidget);
      expect(find.text('More on Bookixo web'), findsNothing);
      final offers = tester.getRect(tile(AppStrings.offers));
      final credits = tester.getRect(tile(AppStrings.creditsPackages));
      final membership = tester.getRect(tile(AppStrings.membership));
      expect(offers.width, 169);
      expect(offers.left, dashboard.right + 12);
      expect(offers.top, dashboard.top);
      expect(credits.top - offers.bottom, 12);
      expect(credits.left, dashboard.left);
      expect(membership.left, credits.right + 12);
      expect(membership.top, credits.top);
      expect(membership.height, credits.height);
      final services = tester.getRect(tile(AppStrings.catalogueServices));
      final users = tester.getRect(tile(AppStrings.shopUsers));
      final settings = tester.getRect(tile(AppStrings.shopSettings));
      expect(users.left, services.right + AppTokens.homeGridGap);
      expect(users.top, services.top);
      expect(settings.width, operations.width);
      expect(settings.left, operations.left);
      expect(settings.top, greaterThan(services.bottom));
      expect(offers.height, greaterThanOrEqualTo(48));
      final dashboardIcon = find.byWidgetPredicate(
        (widget) =>
            widget is BrandBackground &&
            widget.kind == BrandBackgroundKind.dashboardIcon,
      );
      expect(tester.getRect(dashboardIcon).height, AppTokens.homeCardIconSize);
      expect(
        tester.getRect(find.byIcon(Icons.bar_chart)).top,
        lessThan(tester.getRect(find.text(AppStrings.homeDashboard)).top),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Offers.*Web only')), findsNothing);
      expect(
        tester.getSemantics(tile(AppStrings.offers)),
        matchesSemantics(
          label: AppStrings.offers,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(tile(AppStrings.creditsPackages)),
        matchesSemantics(
          label: '${AppStrings.creditsPackages}, ${AppStrings.webOnly}',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
      await tester.tap(find.text(AppStrings.offers));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.offersNotice), findsOneWidget);
      expect(logger.tileTaps, 1);
      expect(find.text(AppStrings.unavailableWeb), findsNothing);
      expect(logger.buttonTaps, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home paints to the status bar while content and bottom stay safe',
    (tester) async {
      await pump(tester, const Size(390, 780), 1);
      final originalHeader = tester.getRect(find.byType(HomeHeader));
      final originalOperations = tester.getRect(tile(AppStrings.operations));
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 34);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();

      final background = find.byWidgetPredicate(
        (widget) =>
            widget is BrandBackground &&
            widget.kind == BrandBackgroundKind.header,
      );
      final header = tester.getRect(background);
      final operations = tester.getRect(tile(AppStrings.operations));
      expect(header.top, 0);
      expect(header.height, originalHeader.height + 28);
      expect(
        tester.getTopLeft(find.byType(HomeProfile)).dy,
        greaterThanOrEqualTo(28 + AppTokens.homeInset),
      );
      expect(
        header.bottom - operations.top,
        originalHeader.bottom - originalOperations.top,
      );
      expect(tester.getBottomRight(find.byType(ListView)).dy, 780 - 34);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, EdgeInsets.zero);
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(HomeHeader),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      final calls = logos.calls.length;
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(logos.calls.length, calls + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual and resumed Home refresh logo independently of menu age',
    (tester) async {
      await pump(tester, const Size(390, 780), 1);
      expect(logos.calls, hasLength(1));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(HomeRefresh));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(AppStrings.refresh));
      await tester.pumpAndSettle();
      expect(logos.calls, hasLength(2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(logos.calls, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  test('Home gradients retain CSS angles and accessible tile colors', () {
    const size = Size(350, 92);
    final operations = AppTokens.tileGradient(size, operations: true);
    final dashboard = AppTokens.tileGradient(size, operations: false);
    final header = AppTokens.homeHeaderGradient(const Size(390, 108));
    expect(operations.colors, [
      const Color(0xFF17A590),
      const Color(0xFF0B7D6E),
    ]);
    expect(dashboard.colors, [
      AppTokens.homeDashboardTileStart,
      AppTokens.homeDashboardTileEnd,
    ]);
    expect(header.colors, [AppTokens.brightBlue, AppTokens.darkBlue]);
    final operationEnd = operations.end.resolve(TextDirection.ltr);
    final headerEnd = header.end.resolve(TextDirection.ltr);
    expect(
      operationEnd.x * size.width,
      closeTo(operationEnd.y * size.height, 0.001),
    );
    expect(headerEnd.x / headerEnd.y, lessThan(1));
  });

  for (final brightness in Brightness.values) {
    testWidgets('Home $brightness rounded surfaces and card hierarchy', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pump(tester, const Size(390, 780), 1);
      final backgrounds = tester.widgetList<BrandBackground>(
        find.byType(BrandBackground),
      );
      expect(backgrounds.map((b) => b.kind), [
        BrandBackgroundKind.header,
        BrandBackgroundKind.operations,
        BrandBackgroundKind.dashboard,
        BrandBackgroundKind.dashboardIcon,
        BrandBackgroundKind.offers,
        BrandBackgroundKind.credits,
        BrandBackgroundKind.membership,
        BrandBackgroundKind.services,
        BrandBackgroundKind.shopUsers,
        BrandBackgroundKind.shopSettings,
      ]);
      for (final definition in MobileMenuRegistry.tiles) {
        final ink = tester.widget<InkWell>(
          find.descendant(
            of: tile(definition.title),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          ink.borderRadius,
          BorderRadius.circular(
            definition.background == BrandBackgroundKind.operations ? 22 : 18,
          ),
        );
      }
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.5]) {
      testWidgets(
        '320x568 $brightness scale $scale grows and scrolls without overflow',
        (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          await pump(tester, const Size(320, 568), scale);
          final operations = tester.getRect(tile(AppStrings.operations));
          expect(operations.width, 280);
          if (scale > 1) expect(operations.height, greaterThan(100));
          await tester.scrollUntilVisible(
            find.text(AppStrings.membership),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.getRect(tile(AppStrings.offers)).width, 280);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(HomeRefresh));
          expect(
            tester.getSize(find.byTooltip(AppStrings.refresh)).height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('grid uses exact width and text-scale thresholds', (
    tester,
  ) async {
    await pump(tester, const Size(372, 780), 1);
    final dashboard = tester.getRect(tile(AppStrings.homeDashboard));
    final offers = tester.getRect(tile(AppStrings.offers));
    expect(dashboard.width, 160);
    expect(offers.left, dashboard.right + 12);

    await pump(tester, const Size(371, 780), 1);
    expect(tester.getRect(tile(AppStrings.homeDashboard)).width, 331);
    expect(
      tester.getRect(tile(AppStrings.offers)).top,
      greaterThan(tester.getRect(tile(AppStrings.homeDashboard)).bottom),
    );

    await pump(tester, const Size(390, 780), 1.3);
    final atLimitDashboard = tester.getRect(tile(AppStrings.homeDashboard));
    final atLimitOffers = tester.getRect(tile(AppStrings.offers));
    expect(atLimitOffers.left, atLimitDashboard.right + 12);

    await pump(tester, const Size(390, 780), 1.31);
    expect(
      tester.getRect(tile(AppStrings.offers)).top,
      greaterThan(tester.getRect(tile(AppStrings.homeDashboard)).bottom),
    );

    await pump(tester, const Size(1200, 780), 1);
    final wideDashboard = tester.getRect(tile(AppStrings.homeDashboard));
    final wideOffers = tester.getRect(tile(AppStrings.offers));
    expect(wideDashboard.left, 220);
    expect(wideDashboard.width, 374);
    expect(wideOffers.left, wideDashboard.right + 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'permission refresh handles absent Operations and odd grid rows',
    (tester) async {
      await pump(tester, const Size(390, 780), 1);
      menu.keys = {'shopdashboard'};
      await container.read(menuControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.byType(HomeTile), findsOneWidget);
      expect(find.text(AppStrings.operations), findsNothing);
      expect(tester.getRect(tile(AppStrings.homeDashboard)).width, 350);

      menu.keys = {'shopdashboard', 'shop-offers-2', 'shop-memberships'};
      await container.read(menuControllerProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.byType(HomeTile), findsNWidgets(3));
      final dashboard = tester.getRect(tile(AppStrings.homeDashboard));
      final offers = tester.getRect(tile(AppStrings.offers));
      final membership = tester.getRect(tile(AppStrings.membership));
      expect(offers.left, dashboard.right + 12);
      expect(membership.left, dashboard.left);
      expect(membership.width, 350);
      expect(membership.top, greaterThan(dashboard.bottom));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home owner switches salon from the named profile control', (
    tester,
  ) async {
    shops.result = ShopContext(const [
      Shop(15, 'Salon A'),
      Shop(16, 'Salon B'),
    ], 15);
    await pump(tester, const Size(390, 780), 1);
    final semantics = tester.ensureSemantics();
    final homeSwitch = find.byKey(const ValueKey('home-salon-switch'));
    expect(homeSwitch, findsOneWidget);
    expect(
      tester.getSemantics(homeSwitch),
      matchesSemantics(
        label: 'Switch salon, Salon A',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
    await tester.tap(homeSwitch);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.chooseSalon), findsOneWidget);
    await tester.tap(find.text('Salon B'));
    await tester.pumpAndSettle();
    expect(container.read(selectedShopProvider)?.id, 16);
    expect(
      tester.getSemantics(homeSwitch),
      matchesSemantics(
        label: 'Switch salon, Salon B',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long salon names wrap without clipping or removing logout', (
    tester,
  ) async {
    shops.result = ShopContext(const [
      Shop(15, 'The Very Long Salon Name That Must Remain Fully Visible'),
    ], 15);
    await pump(tester, const Size(320, 568), 1.3);
    expect(
      find.textContaining(
        'The Very Long Salon Name That Must Remain Fully Visible',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(HomeLogout)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'employee Home keeps a static salon name with no switch affordance',
    (tester) async {
      shops.result = ShopContext(const [
        Shop(15, 'Salon A'),
        Shop(16, 'Salon B'),
      ], 15);
      auth.restored = sampleSession(groups: ['shop_employee']);
      menu.keys = {'shopdashboard'};
      await pump(tester, const Size(390, 780), 1);
      expect(find.text('Salon A · Employee'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-salon-switch')), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
