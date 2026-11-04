import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/core/widgets/shop_header_title.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget withShop(Widget child, {String? name}) => ProviderScope(
    overrides: [
      selectedShopProvider.overrideWithValue(
        name == null ? null : Shop(15, name),
      ),
    ],
    child: child,
  );

  for (final brightness in Brightness.values) {
    testWidgets('canonical styling and accessible back in $brightness', (
      tester,
    ) async {
      var backs = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        withShop(
          MaterialApp(
            theme: AppTheme.forBrightness(brightness),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 600),
                  padding: EdgeInsets.only(top: 24),
                ),
                child: AppInnerHeader(
                  title: AppStrings.bookingDetails,
                  onBack: () => backs++,
                ),
              ),
            ),
          ),
        ),
      );

      final title = tester.widget<Text>(find.text(AppStrings.bookingDetails));
      expect(title.style?.color, AppTokens.white);
      expect(title.style?.fontSize, AppTokens.innerHeaderTitleSize);
      expect(title.style?.fontWeight, FontWeight.w600);
      final back = find.byTooltip(AppStrings.back);
      expect(
        tester.getSize(back).width,
        greaterThanOrEqualTo(AppTokens.target),
      );
      expect(
        tester.getSize(back).height,
        greaterThanOrEqualTo(AppTokens.target),
      );
      expect(
        tester.getTopLeft(back),
        const Offset(
          AppTokens.innerHeaderHorizontal,
          24 + AppTokens.innerHeaderTop,
        ),
      );
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == AppStrings.back,
        ),
      );
      expect(
        button.style?.backgroundColor?.resolve({}),
        AppTokens.white.withValues(alpha: AppTokens.innerHeaderTranslucency),
      );
      expect(
        (button.style?.shape?.resolve(
          {},
        ) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppTokens.controlRadius),
      );
      expect(
        tester.getBottomRight(find.byType(AppInnerHeader)).dy -
            tester.getBottomRight(back).dy,
        AppTokens.innerHeaderBottom,
      );
      final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(AppInnerHeader),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarIconBrightness, Brightness.light);
      final painted = find
          .descendant(
            of: find.byType(AppInnerHeader),
            matching: find.byType(CustomPaint),
          )
          .first;
      expect(
        painted,
        paints..rrect(
          rrect: const BorderRadius.vertical(
            bottom: Radius.circular(AppTokens.innerHeaderRadius),
          ).toRRect(Offset.zero & tester.getSize(painted)),
        ),
      );
      expect(
        tester.getSemantics(back),
        matchesSemantics(
          tooltip: AppStrings.back,
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      await tester.tap(back);
      expect(backs, 1);
      semantics.dispose();
    });
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('trailing badge and action fit narrow layout at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var actions = 0;
      await tester.pumpWidget(
        withShop(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: AppInnerHeader(
                  title: AppStrings.offers,
                  onBack: () {},
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AppInnerHeaderBadge(
                          label: AppStrings.offersWithActiveRules(1234),
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.refresh,
                        onPressed: () => actions++,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.offersWithActiveRules(1234)), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AppInnerHeaderBadge)).dy,
        greaterThan(tester.getBottomRight(find.text(AppStrings.offers)).dy),
      );
      await tester.tap(find.byTooltip(AppStrings.refresh));
      expect(actions, 1);
    });
  }

  testWidgets('back pops a pushed route and uses fallback on direct entry', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/details',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/details'),
              child: const Text(AppStrings.operations),
            ),
          ),
        ),
        GoRoute(
          path: '/details',
          builder: (_, _) => const Scaffold(
            body: AppInnerHeader(title: AppStrings.bookingDetails),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(withShop(MaterialApp.router(routerConfig: router)));
    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    await tester.tap(find.text(AppStrings.operations));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.operations), findsOneWidget);
  });

  test('shop abbreviation handles whitespace, punctuation and Unicode', () {
    final cases = <String?, String>{
      null: '',
      '': '',
      ' \t\n ': '',
      ' & ... — ': '',
      'glow': 'GLOW',
      ' sb ': 'SB',
      'GlowSalon': 'GLOW',
      '  salon \n\t bliss  ': 'SB',
      '  "Glow!"  ': 'GLOW',
      'Glow & Bliss': 'GB',
      'Glow-Spa / Studio': 'GSS',
      'Éclat beauté': 'ÉB',
      'e\u0301clat': 'E\u0301CLA',
      '123 salon': '1S',
      '💇 Glow 🌟': 'GLOW',
      '東京': '東京',
    };
    for (final entry in cases.entries) {
      expect(shopAbbreviation(entry.key), entry.value, reason: entry.key);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('long selected salon fits compact header in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final name = List.filled(80, 'Salon').join(' ');
      await tester.pumpWidget(
        withShop(
          MaterialApp(
            theme: AppTheme.forBrightness(brightness),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                child: const AppInnerHeader(
                  title: AppStrings.creditsPackages,
                  trailing: AppInnerHeaderBadge(label: AppStrings.webOnly),
                ),
              ),
            ),
          ),
          name: name,
        ),
      );
      final title = tester.widget<Text>(
        find.text('${AppStrings.creditsPackages} · ${'S' * 80}'),
      );
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('title follows selected shop changes and clears stale suffix', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        selectedShopProvider.overrideWithValue(const Shop(15, 'Glow')),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AppInnerHeader(title: AppStrings.operations)),
        ),
      ),
    );
    expect(find.text('Operations · GLOW'), findsOneWidget);
    container.updateOverrides([
      selectedShopProvider.overrideWithValue(const Shop(16, 'Salon Bliss')),
    ]);
    await tester.pump();
    expect(find.text('Operations · SB'), findsOneWidget);
    container.updateOverrides([selectedShopProvider.overrideWithValue(null)]);
    await tester.pump();
    expect(find.text(AppStrings.operations), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
  });
}
