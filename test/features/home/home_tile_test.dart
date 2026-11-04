import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/core/widgets/brand_background.dart';
import 'package:bookixo_pro/features/home/presentation/home_screen.dart';
import 'package:bookixo_pro/features/home/presentation/home_tile.dart';
import 'package:bookixo_pro/features/home/presentation/home_tile_icon.dart';
import 'package:bookixo_pro/features/menu/presentation/mobile_menu_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpTiles(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      theme: AppTheme.forBrightness(brightness),
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: HomeFeatureGrid(
              tiles: MobileMenuRegistry.tiles.skip(1).toList(),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder iconSquare(String title) => find.byWidgetPredicate(
  (widget) => widget is HomeTileIcon && widget.tile.title == title,
);

Finder card(String title) => find.byWidgetPredicate(
  (widget) => widget is HomeTile && widget.tile.title == title,
);

Finder within(Finder parent, Type type) =>
    find.descendant(of: parent, matching: find.byType(type));

double opacity(WidgetTester tester, Finder icon) =>
    tester.widget<FadeTransition>(within(icon, FadeTransition)).opacity.value;

double entranceScale(WidgetTester tester, Finder icon) => tester
    .widget<ScaleTransition>(within(icon, ScaleTransition).first)
    .scale
    .value;

double pressScale(WidgetTester tester, Finder icon) => tester
    .widget<ScaleTransition>(within(icon, ScaleTransition).last)
    .scale
    .value;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness feature cards use readable gradient fills', (
      tester,
    ) async {
      await pumpTiles(tester, brightness: brightness);
      await tester.pumpAndSettle();
      final dark = brightness == Brightness.dark;
      final expected = [
        (
          AppStrings.offers,
          dark
              ? AppTokens.homeOffersIconDarkBackground
              : AppTokens.homeOffersIconBackground,
        ),
        (
          AppStrings.creditsPackages,
          dark
              ? AppTokens.homeCreditsIconDarkBackground
              : AppTokens.homeCreditsIconBackground,
        ),
        (
          AppStrings.membership,
          dark
              ? AppTokens.homeMembershipIconDarkBackground
              : AppTokens.homeMembershipIconBackground,
        ),
      ];
      expect(expected.map((pair) => pair.$2).toSet(), hasLength(3));
      for (final (title, background) in expected) {
        final icon = iconSquare(title);
        final decoration =
            tester.widget<DecoratedBox>(within(icon, DecoratedBox)).decoration
                as BoxDecoration;
        expect(decoration.color, background);
        expect(
          decoration.borderRadius,
          BorderRadius.circular(AppTokens.homeCardIconRadius),
        );
        final iconColor = tester.widget<Icon>(within(icon, Icon)).color;
        expect(iconColor, AppTokens.white);
        expect(
          tester.getSize(icon),
          const Size(AppTokens.homeCardIconSize, AppTokens.homeCardIconSize),
        );
        final contrast =
            (AppTokens.white.computeLuminance() + 0.05) /
            (background.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
      final gradients = {
        AppStrings.homeDashboard: [
          AppTokens.homeDashboardTileStart,
          AppTokens.homeDashboardTileEnd,
        ],
        AppStrings.offers: [AppTokens.offersStart, AppTokens.offersEnd],
        AppStrings.creditsPackages: [
          AppTokens.creditsStart,
          AppTokens.creditsEnd,
        ],
        AppStrings.membership: [
          AppTokens.membershipStart,
          AppTokens.membershipEnd,
        ],
        AppStrings.catalogueServices: [
          AppTokens.servicesStart,
          AppTokens.servicesEnd,
        ],
        AppStrings.shopUsers: [
          AppTokens.shopUsersStart,
          AppTokens.shopUsersEnd,
        ],
        AppStrings.shopSettings: [
          AppTokens.shopSettingsStart,
          AppTokens.shopSettingsEnd,
        ],
      };
      for (final definition in MobileMenuRegistry.tiles.skip(1)) {
        expect(
          tester
              .widget<BrandBackground>(
                within(card(definition.title), BrandBackground).first,
              )
              .kind,
          definition.background,
        );
        final titleStyle = tester
            .widget<Text>(
              find.descendant(
                of: card(definition.title),
                matching: find.text(definition.title),
              ),
            )
            .style;
        expect(titleStyle?.color, AppTokens.white);
        for (final color in gradients[definition.title]!) {
          expect(
            (AppTokens.white.computeLuminance() + 0.05) /
                (color.computeLuminance() + 0.05),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
      final dashboard = iconSquare(AppStrings.homeDashboard);
      expect(
        tester.widget<BrandBackground>(within(dashboard, BrandBackground)).kind,
        BrandBackgroundKind.dashboardIcon,
      );
      final dashboardIconColor = tester
          .widget<Icon>(within(dashboard, Icon))
          .color;
      expect(dashboardIconColor, AppTokens.white);
      for (final background in [
        AppTokens.homeDashboardTileStart,
        AppTokens.homeDashboardTileEnd,
      ]) {
        expect(
          (AppTokens.white.computeLuminance() + 0.05) /
              (background.computeLuminance() + 0.05),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('icon entrance fades and scales once without moving cards', (
    tester,
  ) async {
    await pumpTiles(tester);
    final before = tester.getRect(card(AppStrings.homeDashboard));
    final squareBefore = tester.getRect(iconSquare(AppStrings.homeDashboard));
    for (final definition in MobileMenuRegistry.tiles.skip(1)) {
      final icon = iconSquare(definition.title);
      expect(opacity(tester, icon), 0);
      expect(entranceScale(tester, icon), AppTokens.homeIconEntranceScale);
      expect(pressScale(tester, icon), 1);
    }

    await tester.pump(const Duration(milliseconds: 110));
    for (final definition in MobileMenuRegistry.tiles.skip(1)) {
      final icon = iconSquare(definition.title);
      expect(opacity(tester, icon), allOf(greaterThan(0), lessThan(1)));
      expect(
        entranceScale(tester, icon),
        allOf(greaterThan(AppTokens.homeIconEntranceScale), lessThan(1)),
      );
    }
    await tester.pump(AppTokens.homeIconEntranceDuration);
    expect(tester.getRect(card(AppStrings.homeDashboard)), before);
    expect(tester.getRect(iconSquare(AppStrings.homeDashboard)), squareBefore);
    expect(tester.binding.hasScheduledFrame, isFalse);

    // Theme/parent rebuilds must not restart decorative entrance.
    await pumpTiles(tester, brightness: Brightness.dark);
    for (final definition in MobileMenuRegistry.tiles.skip(1)) {
      final icon = iconSquare(definition.title);
      expect(opacity(tester, icon), 1);
      expect(entranceScale(tester, icon), 1);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'press and cancel scale only the icon, without replaying entrance',
    (tester) async {
      await pumpTiles(tester);
      await tester.pumpAndSettle();
      final target = card(AppStrings.homeDashboard);
      final icon = iconSquare(AppStrings.homeDashboard);
      final before = tester.getRect(target);
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(within(icon, AnimatedScale)).scale,
        AppTokens.homeIconPressScale,
      );
      await tester.pump(AppTokens.homeIconPressDuration);
      expect(
        pressScale(tester, icon),
        closeTo(AppTokens.homeIconPressScale, 0.001),
      );
      expect(opacity(tester, icon), 1);
      expect(entranceScale(tester, icon), 1);
      expect(tester.getRect(target), before);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(pressScale(tester, icon), 1);
      expect(tester.getRect(target), before);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      '${accessibleNavigation ? 'accessibleNavigation' : 'disableAnimations'} skips entrance and press motion',
      (tester) async {
        await pumpTiles(
          tester,
          disableAnimations: !accessibleNavigation,
          accessibleNavigation: accessibleNavigation,
        );
        for (final definition in MobileMenuRegistry.tiles.skip(1)) {
          final icon = iconSquare(definition.title);
          expect(within(icon, FadeTransition), findsNothing);
          expect(within(icon, ScaleTransition), findsNothing);
          expect(within(icon, AnimatedScale), findsNothing);
          expect(within(icon, Icon), findsOneWidget);
        }
        final target = card(AppStrings.homeDashboard);
        final icon = iconSquare(AppStrings.homeDashboard);
        final before = tester.getRect(icon);
        final gesture = await tester.startGesture(tester.getCenter(target));
        await tester.pumpAndSettle();
        expect(within(icon, AnimatedScale), findsNothing);
        expect(tester.getRect(icon), before);
        await gesture.cancel();
        await tester.pumpAndSettle();

        // Turning motion back on does not play a skipped entrance.
        await pumpTiles(tester);
        expect(opacity(tester, icon), 1);
        expect(entranceScale(tester, icon), 1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('reduce motion enabled mid-entrance settles immediately', (
    tester,
  ) async {
    await pumpTiles(tester);
    await tester.pump(const Duration(milliseconds: 60));
    final icon = iconSquare(AppStrings.offers);
    expect(opacity(tester, icon), lessThan(1));
    await pumpTiles(tester, disableAnimations: true);
    expect(within(icon, FadeTransition), findsNothing);
    expect(within(icon, ScaleTransition), findsNothing);
    await pumpTiles(tester);
    expect(opacity(tester, icon), 1);
    expect(entranceScale(tester, icon), 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduce motion enabled during a press removes scaling immediately',
    (tester) async {
      await pumpTiles(tester);
      await tester.pumpAndSettle();
      final target = card(AppStrings.homeDashboard);
      final icon = iconSquare(AppStrings.homeDashboard);
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump();
      await tester.pump(AppTokens.homeIconPressDuration);
      expect(
        pressScale(tester, icon),
        closeTo(AppTokens.homeIconPressScale, 0.001),
      );
      await pumpTiles(tester, disableAnimations: true);
      expect(within(icon, AnimatedScale), findsNothing);
      expect(
        tester.getSize(icon),
        const Size(AppTokens.homeCardIconSize, AppTokens.homeCardIconSize),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing an entering icon releases its ticker', (tester) async {
    await pumpTiles(tester);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
