import 'dart:async';

import 'package:bookixo_pro/app.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/routing/app_router.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../features/menu/controller_test.dart' show FakeMenuRepository;
import '../../features/home/logo_controller_test.dart' show FakeLogoRepository;

void main() {
  late FakeAuthRepository auth;
  late FakeShopRepository shop;
  late ProviderContainer container;
  setUp(() {
    auth = FakeAuthRepository();
    shop = FakeShopRepository();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(shop),
        shopLogoRepositoryProvider.overrideWithValue(FakeLogoRepository()),
        clockProvider.overrideWithValue(FakeClock()),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
        menuRepositoryProvider.overrideWithValue(
          FakeMenuRepository(MenuCacheStore(MemoryBackend()), FakeClock()),
        ),
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

  test('every route target respects session and shop gate', () {
    final owner = AuthView(sampleSession().identity, 1);
    final ready = AsyncData<ShopContext?>(
      ShopContext(const [Shop(15, 'Test salon')], 15),
    );
    expect(sessionDestination(const AsyncLoading(), ready), '/');
    expect(
      sessionDestination(
        AsyncError(const StorageFailure(), StackTrace.empty),
        ready,
      ),
      '/',
    );
    expect(
      sessionDestination(const AsyncData(AuthView(null, 0)), ready),
      '/login',
    );
    expect(sessionDestination(AsyncData(owner), const AsyncLoading()), '/shop');
    expect(
      sessionDestination(AsyncData(owner), AsyncData(ShopContext([], null))),
      '/shop',
    );
    final menu = AsyncData<MenuView?>(
      MenuView(
        MenuSnapshot(const MenuScope('5', null, 15), {
          'shopdashboard',
        }, testNow),
      ),
    );
    expect(sessionDestination(AsyncData(owner), ready, menu: menu), '/home');
    expect(
      sessionDestination(
        AsyncData(
          AuthView(sampleSession(groups: ['shop_employee']).identity, 1),
        ),
        ready,
        menu: menu,
      ),
      '/home',
    );
    expect(
      sessionDestination(
        AsyncData(AuthView(sampleSession(groups: []).identity, 1)),
        ready,
      ),
      '/unsupported',
    );
  });
  testWidgets('signed-out protected deep link goes to login', (tester) async {
    await pump(tester);
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text(AppStrings.ownerPlaceholder), findsNothing);
  });
  testWidgets('startup gate does not flash previous landing', (tester) async {
    auth.restoreGate = Completer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pump();
    expect(find.text(AppStrings.loading), findsOneWidget);
    expect(find.textContaining(AppStrings.ownerPlaceholder), findsNothing);
    auth.restoreGate?.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });
  for (final entry in [
    (groups: ['OWNER'], wrong: '/scan', target: AppStrings.operationsSubtitle),
    (
      groups: ['shop_employee'],
      wrong: '/scan',
      target: AppStrings.operationsSubtitle,
    ),
  ]) {
    testWidgets('menu landing defers attendance for ${entry.groups}', (
      tester,
    ) async {
      auth.restored = sampleSession(groups: entry.groups);
      await pump(tester);
      container.read(routerProvider).go(entry.wrong);
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.target), findsOneWidget);
      expect(find.textContaining('price'), findsNothing);
      expect(find.text(AppStrings.demo), findsNothing);
      await tester.tap(find.byTooltip(AppStrings.logout));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(container.read(shopContextProvider).asData?.value, isNull);
    });
  }
  testWidgets('unsupported role does not request shop or land owner', (
    tester,
  ) async {
    auth.restored = sampleSession(groups: ['unrecognized']);
    await pump(tester);
    container.read(routerProvider).go('/home');
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.unsupported), findsOneWidget);
    expect(shop.calls, 0);
    expect(find.text(AppStrings.logout), findsOneWidget);
  });
  testWidgets('empty owner shops gate has Retry without Logout', (
    tester,
  ) async {
    auth.restored = sampleSession();
    shop.result = ShopContext([], null);
    await pump(tester);
    expect(find.text(AppStrings.noShop), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.logout), findsNothing);
    expect(find.textContaining(AppStrings.ownerPlaceholder), findsNothing);
    shop.result = ShopContext(const [Shop(15, 'Test salon')], 15);
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.operationsSubtitle), findsOneWidget);
  });
  testWidgets('shop failure shows friendly Retry without pretending empty', (
    tester,
  ) async {
    auth.restored = sampleSession();
    shop.failure = const NetworkFailure();
    await pump(tester);
    expect(find.text(AppStrings.network), findsOneWidget);
    expect(find.text(AppStrings.noShop), findsNothing);
    shop.failure = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.operationsSubtitle), findsOneWidget);
  });
  testWidgets('logout during context loading discards old-user response', (
    tester,
  ) async {
    auth.restored = sampleSession(groups: ['shop_employee']);
    shop.gate = Completer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(AppStrings.shopLoading), findsOneWidget);
    await tester.tap(find.text(AppStrings.logout));
    await tester.pumpAndSettle();
    shop.gate?.complete(ShopContext(const [Shop(15, 'Old salon')], 15));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(container.read(shopContextProvider).asData?.value, isNull);
  });
  testWidgets('login double taps disabled; failure retains input', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).at(0), 'owner@example.test');
    await tester.enterText(find.byType(TextField).at(1), ' test ');
    auth.signInGate = Completer();
    await tester.tap(find.text(AppStrings.login));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(auth.signs, 1);
    auth.signInGate?.completeError(const NetworkFailure(), StackTrace.empty);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
      'owner@example.test',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
      ' test ',
    );
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
  testWidgets('challenge stays login with contact guidance', (tester) async {
    auth.signInResult = const ActionRequired();
    await pump(tester);
    await tester.enterText(
      find.byType(TextField).at(0),
      'challenge@example.test',
    );
    await tester.enterText(find.byType(TextField).at(1), 'test');
    await tester.tap(find.text(AppStrings.login));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.challenge), findsOneWidget);
    expect(shop.calls, 0);
  });
  for (final brightness in Brightness.values) {
    testWidgets('login $brightness supports large text without overflow', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
