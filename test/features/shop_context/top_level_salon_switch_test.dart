import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/dashboard/data/mock_dashboard_repository.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_models.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_controller.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_screen.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_screen.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/upsell/presentation/web_feature_screen.dart';
import 'package:bookixo_pro/features/menu/presentation/mobile_menu_registry.dart';
import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class TopLevelMenuController extends MenuController {
  @override
  Future<MenuView?> build() async => MenuView(
    MenuSnapshot(const MenuScope('5', 'subject', 15), const {
      'shopdashboard',
      'shop-offers-2',
      'shop-credits-packages',
      'shop-memberships',
    }, testNow),
  );
}

void main() {
  final shopContext = ShopContext(const [
    Shop(15, 'Salon A'),
    Shop(16, 'Salon B'),
  ], 15);
  const menuScope = MenuScope('5', 'subject', 15);
  const accessibleFeatures = {
    'shopdashboard',
    'shop-offers-2',
    'shop-credits-packages',
    'shop-memberships',
  };
  final topLevelScreens = <({String title, Widget screen})>[
    (title: AppStrings.dashboard, screen: const DashboardScreen()),
    (title: AppStrings.offers, screen: const OffersScreen()),
    (
      title: AppStrings.creditsPackages,
      screen: WebFeatureScreen(tile: MobileMenuRegistry.tiles[3]),
    ),
    (
      title: AppStrings.membership,
      screen: WebFeatureScreen(tile: MobileMenuRegistry.tiles[4]),
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    bool employee = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(
            AppConfig.parse('https://example.test', debug: true, demo: true),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()
              ..restored = sampleSession(
                groups: [employee ? 'shop_employee' : 'shop_owner'],
              ),
          ),
          clockProvider.overrideWithValue(FakeClock()),
          shopContextProvider.overrideWith((_) async => shopContext),
          selectedShopProvider.overrideWithValue(shopContext.shops.first),
          menuControllerProvider.overrideWith(TopLevelMenuController.new),
          dashboardAccessProvider.overrideWithValue((
            scope: DashboardScope(menu: menuScope, ownership: 1),
            features: accessibleFeatures,
          )),
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository(),
          ),
          offersScopeProvider.overrideWithValue((
            scope: menuScope,
            ownership: 1,
            shop: shopContext.shops.first,
          )),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final destination in topLevelScreens) {
    testWidgets(
      '${destination.title} preserves existing employee actions without switching',
      (tester) async {
        await pumpScreen(tester, destination.screen, employee: true);
        expect(find.text('${destination.title} · SA'), findsOneWidget);
        expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
        expect(find.byIcon(Icons.storefront_outlined), findsNothing);
        final upsell = destination.screen is WebFeatureScreen;
        expect(
          find.byTooltip(AppStrings.logout),
          upsell ? findsOneWidget : findsNothing,
        );
        expect(
          find.byIcon(Icons.refresh),
          upsell ? findsOneWidget : findsNothing,
        );
        if (destination.title == AppStrings.offers) {
          expect(find.byType(AppInnerHeaderBadge), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${destination.title} retains its title with selected salon and no owner controls',
      (tester) async {
        await pumpScreen(tester, destination.screen);
        final header = find.byType(AppInnerHeader);
        expect(header, findsOneWidget);
        expect(
          find.descendant(
            of: header,
            matching: find.text('${destination.title} · SA'),
          ),
          findsOneWidget,
        );
        final switchAction = find.widgetWithText(
          TextButton,
          AppStrings.switchSalon,
        );
        expect(switchAction, findsNothing);
        expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
        expect(find.byIcon(Icons.storefront_outlined), findsNothing);
        expect(find.byIcon(Icons.logout), findsNothing);

        if (destination.title == AppStrings.offers) {
          expect(find.byType(AppInnerHeaderBadge), findsOneWidget);
        }
        if (destination.title == AppStrings.creditsPackages ||
            destination.title == AppStrings.membership) {
          expect(find.byIcon(Icons.refresh), findsOneWidget);
        }

        expect(tester.takeException(), isNull);
      },
    );
  }
}
