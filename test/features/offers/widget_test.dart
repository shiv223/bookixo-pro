import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/offers/data/offers_dto.dart';
import 'package:bookixo_pro/features/offers/data/voucher_capture.dart';
import 'package:bookixo_pro/features/offers/domain/offer.dart';
import 'package:bookixo_pro/features/offers/domain/offers_repository.dart';
import 'package:bookixo_pro/features/offers/presentation/offer_details_screen.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_screen.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_widgets.dart';
import 'package:bookixo_pro/features/offers/presentation/voucher_card.dart';
import 'package:bookixo_pro/features/offers/presentation/voucher_export_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';
import 'contract_test.dart';
import 'controller_test.dart';
import 'export_test.dart';

class OffersTestAuth extends AuthController {
  static bool owner = true;
  @override
  Future<AuthView> build() async => AuthView(
    AuthIdentity(
      userId: '5',
      email: 'test@example.test',
      groups: [owner ? 'OWNER' : 'shop_employee'],
    ),
    1,
    ownership: 1,
  );
}

void main() {
  late FakeOffersRepository repo;
  late ProviderContainer container;
  late FakeVoucherPlatform platform;
  setUp(() {
    repo = FakeOffersRepository();
    platform = FakeVoucherPlatform();
    OffersTestAuth.owner = true;
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true, demo: true),
        ),
        offersScopeProvider.overrideWith((ref) => ref.watch(testScopeProvider)),
        offersRepositoryProvider.overrideWithValue(repo),
        voucherPlatformProvider.overrideWithValue(platform),
        authControllerProvider.overrideWith(OffersTestAuth.new),
        shopContextProvider.overrideWith(
          (_) async =>
              ShopContext(const [Shop(15, 'Salon A'), Shop(16, 'Salon B')], 15),
        ),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 10, 8, 12))),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(
    WidgetTester tester, {
    Widget screen = const OffersScreen(),
    ThemeMode mode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          darkTheme: AppTheme.forBrightness(Brightness.dark),
          themeMode: mode,
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mixed raw rules merge into one compact readonly ticket', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.rulePages = 2;
    repo.ruleItems = [
      OffersDto.rule(ruleJson()),
      OffersDto.rule({...ruleJson(id: 2), 'isActive': true}),
      OffersDto.rule({...ruleJson(id: 3), 'isActive': true}),
    ];
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(OfferTicket), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Rule '), findsNothing);
    expect(find.byType(DayCircles), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(tester.getSize(find.byType(OfferTicket)).height, lessThan(180));
    final valuePosition = tester.getTopLeft(
      find.byKey(const ValueKey('discount-1')),
    );
    final titlePosition = tester.getTopLeft(find.text('BINGO DISCOUNT'));
    expect(valuePosition.dx, lessThan(titlePosition.dx));
    final block = tester.widget<Container>(
      find.byKey(const ValueKey('discount-1')),
    );
    expect((block.decoration as BoxDecoration).color, AppTokens.primary);
    expect((block.decoration as BoxDecoration).gradient, isNotNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('1 offers with active rules'), findsOneWidget);
    semantics.dispose();
  });
  for (final discount in ['FLAT', 'PERCENT', 'OTHER']) {
    testWidgets(
      'ticket $discount value/format/color independent of inactive rule',
      (tester) async {
        repo.offerItems = [
          OffersDto.offer({
            ...offerJson(),
            'discountType': discount,
            'discountValue': 12.500,
          }),
        ];
        await pump(tester);
        await tester.pumpAndSettle();
        expect(
          find.text(
            discount == 'OTHER'
                ? AppStrings.discountUnavailable
                : discount == 'PERCENT'
                ? '12.5%'
                : '12.5',
          ),
          findsOneWidget,
        );
        final block = tester.widget<Container>(
          find.byKey(const ValueKey('discount-1')),
        );
        final color = (block.decoration as BoxDecoration).color;
        if (discount == 'FLAT') expect(color, AppTokens.primary);
        if (discount == 'PERCENT') expect(color, AppTokens.accent);
        if (discount == 'OTHER') {
          expect(color, isNot(AppTokens.primary));
          expect(color, isNot(AppTokens.accent));
        }
        expect(
          (block.decoration as BoxDecoration).gradient,
          discount == 'OTHER' ? isNull : isNotNull,
        );
        expect(find.byType(Switch), findsNothing);
      },
    );
  }
  testWidgets('entire read-only card opens existing voucher details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/web/offers',
      routes: [
        GoRoute(path: '/web/offers', builder: (_, _) => const OffersScreen()),
        GoRoute(
          path: '/web/offers/:offerId',
          builder: (_, _) => const OfferDetailsScreen(offerId: 1),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.forBrightness(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discount-1')));
    await tester.pumpAndSettle();
    expect(find.byType(VoucherCard), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });
  testWidgets('partial rules never guess Active until complete final page', (
    tester,
  ) async {
    repo.rulePages = 2;
    repo.ruleItems = [
      OffersDto.rule({...ruleJson(), 'isActive': true}),
    ];
    repo.ruleGates[1] = Completer();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.text(AppStrings.ruleStatusUnavailable), findsNWidgets(2));
    expect(find.text('Active (—)'), findsOneWidget);
    expect(find.text('Inactive (—)'), findsOneWidget);
    expect(find.text('0 offers with active rules'), findsNothing);
    expect(
      find.text(
        AppStrings.resourceNotice(
          AppStrings.rulesResource,
          AppStrings.resourcePending,
        ),
      ),
      findsOneWidget,
    );
    repo.ruleGates[1]?.complete(samplePage([], 1));
    await tester.pumpAndSettle();
    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('1 offers with active rules'), findsOneWidget);
  });
  testWidgets('four skeletons then error Retry; empty and unavailable web', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.offerGates[0] = Completer();
    await pump(tester);
    expect(find.byType(OfferSkeleton), findsNWidgets(4));
    repo.offerGates[0]?.completeError(const NetworkFailure(), StackTrace.empty);
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.network), findsOneWidget);
    repo.offerGates.clear();
    repo.offerItems = [];
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.offersEmpty), findsOneWidget);
    expect(find.text(AppStrings.offersNotice), findsOneWidget);
    final web = tester.widget<TextButton>(
      find.widgetWithText(TextButton, AppStrings.openWebUnavailable),
    );
    expect(web.onPressed, isNull);
  });
  testWidgets(
    'all parent offers active but raw rules off gives zero active cards',
    (tester) async {
      repo.offerItems = [
        OffersDto.offer(offerJson()),
        OffersDto.offer({...offerJson(id: 2), 'title': 'Second offer'}),
        OffersDto.offer({...offerJson(id: 3), 'title': 'Third offer'}),
      ];
      repo.ruleItems = [
        for (var id = 1; id <= 3; id++)
          OffersDto.rule({...ruleJson(id: id), 'offerId': id}),
      ];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('0 offers with active rules'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Active (0)'), findsOneWidget);
      expect(find.text('Inactive (3)'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.text(AppStrings.allServices), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
      await tester.tap(find.text('Active (0)'));
      await tester.pumpAndSettle();
      expect(find.text('BINGO DISCOUNT'), findsNothing);
      expect(find.text(AppStrings.noFilteredOffers), findsOneWidget);
      await tester.tap(find.text('Inactive (3)'));
      await tester.pumpAndSettle();
      expect(find.text('BINGO DISCOUNT'), findsOneWidget);
    },
  );
  testWidgets(
    'schedule-first list merges same-window days and keeps separate windows per offer',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo.offerItems = [
        OffersDto.offer(offerJson()),
        OffersDto.offer({
          ...offerJson(id: 2),
          'title': 'Expired offer',
          'endDate': '2026-10-07',
        }),
      ];
      repo.ruleItems = [
        OffersDto.rule(ruleJson()),
        OffersDto.rule({...ruleJson(id: 2), 'dayOfWeek': 4, 'isActive': true}),
        OffersDto.rule({
          ...ruleJson(id: 3),
          'startTime': '10:00:00',
          'endTime': '12:00:00',
        }),
      ];

      await pump(tester);
      await tester.pumpAndSettle();

      expect(find.byType(OfferTicket), findsNWidgets(2));
      expect(find.text('Sun, Wed'), findsOneWidget);
      expect(find.text('Sun · 10:00 to 12:00'), findsOneWidget);
      expect(find.byType(DayCircles), findsNWidgets(2));
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('Inactive (0)'), findsOneWidget);
      expect(find.text(AppStrings.noRules), findsOneWidget);
      expect(find.text('1 offers with active rules'), findsOneWidget);
      expect(find.text('50'), findsNWidgets(2));
      expect(find.text(AppStrings.flatOff), findsNWidgets(2));
      expect(find.byType(Switch), findsNothing);
    },
  );
  testWidgets('offer tap opens detail voucher with its discount and target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/web/offers',
      routes: [
        GoRoute(
          path: '/web/offers',
          builder: (context, state) => const OffersScreen(),
        ),
        GoRoute(
          path: '/web/offers/:offerId',
          builder: (context, state) => OfferDetailsScreen(
            offerId: int.parse(state.pathParameters['offerId'] ?? ''),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.forBrightness(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50'), findsOneWidget);
    expect(find.text(AppStrings.flatOff), findsOneWidget);
    await tester.tap(find.text('BINGO DISCOUNT'));
    await tester.pumpAndSettle();

    expect(find.byType(VoucherCard), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text(AppStrings.flatOff), findsOneWidget);
    expect(find.text(AppStrings.allServices), findsOneWidget);
  });
  testWidgets('complete empty rules preserve validity and colored discount', (
    tester,
  ) async {
    repo.ruleItems = [];
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(OfferTicket), findsOneWidget);
    expect(find.text(AppStrings.noScheduleRules), findsOneWidget);
    expect(find.text(AppStrings.noRules), findsOneWidget);
    expect(find.text('All (1)'), findsOneWidget);
    expect(find.text('Active (0)'), findsOneWidget);
    expect(find.text('Inactive (0)'), findsOneWidget);
    expect(find.text('February 17, 2026 – February 26, 2027'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text(AppStrings.flatOff), findsOneWidget);
  });
  testWidgets('pending rules do not masquerade as an empty schedule', (
    tester,
  ) async {
    final gate = Completer<ResourcePage<ScheduleRule>>();
    repo.ruleGates[0] = gate;
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noScheduleRules), findsNothing);
    expect(find.text(AppStrings.schedulesIncomplete), findsOneWidget);
    expect(
      find.text(
        AppStrings.resourceNotice(
          AppStrings.rulesResource,
          AppStrings.resourcePending,
        ),
      ),
      findsOneWidget,
    );
    gate.complete(samplePage([], 0));
    await tester.pumpAndSettle();
  });
  testWidgets('failed rules show resource retry, not an empty schedule', (
    tester,
  ) async {
    repo.rulesFailure = const NetworkFailure();
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noScheduleRules), findsNothing);
    expect(find.text(AppStrings.schedulesIncomplete), findsOneWidget);
    expect(find.textContaining('Schedules: No connection'), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(find.text(AppStrings.ruleStatusUnavailable), findsNWidgets(2));
    expect(find.text('Active (—)'), findsOneWidget);
    expect(find.text('Inactive (—)'), findsOneWidget);
  });
  testWidgets(
    'capped raw rules remain unavailable despite loaded active rule',
    (tester) async {
      repo.rulePages = 11;
      repo.ruleItems = [
        OffersDto.rule({...ruleJson(), 'isActive': true}),
      ];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.ruleStatusUnavailable), findsNWidgets(2));
      expect(find.text('Active (—)'), findsOneWidget);
      expect(find.text('Inactive (—)'), findsOneWidget);
      expect(find.textContaining(AppStrings.resourceCap), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    },
  );
  testWidgets(
    'unknown active raw schedule still Active but diagnostic retained',
    (tester) async {
      repo.ruleItems = [
        OffersDto.rule({...ruleJson(), 'scheduleType': 'ALWAYS'}),
        OffersDto.rule({
          ...ruleJson(id: 2),
          'scheduleType': 'UNKNOWN',
          'isActive': true,
        }),
      ];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('1 offers with active rules'), findsOneWidget);
      expect(find.text(AppStrings.everyDay), findsOneWidget);
      expect(find.text(AppStrings.invalidSchedule), findsOneWidget);
      expect(
        find.text('February 17, 2026 – February 26, 2027'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
    },
  );
  testWidgets(
    'disabled parent with active raw rule lists Active but cannot share',
    (tester) async {
      repo.offerItems = [
        OffersDto.offer({...offerJson(), 'isActive': false}),
      ];
      repo.ruleItems = [
        OffersDto.rule({...ruleJson(), 'isActive': true}),
      ];
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Active (1)'), findsOneWidget);
      expect(find.text('1 offers with active rules'), findsOneWidget);
      await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.offNote), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppStrings.share),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, AppStrings.saveImage),
            )
            .onPressed,
        isNull,
      );
      expect(platform.shares + platform.saves + platform.permissions, 0);
    },
  );
  testWidgets('pull refresh replaces list but failed refresh retains tickets', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    repo.offerFailurePage = 0;
    await tester.drag(find.byType(ListView), const Offset(0, 450));
    await tester.pumpAndSettle();
    expect(find.text('BINGO DISCOUNT'), findsOneWidget);
    expect(find.textContaining(AppStrings.network), findsOneWidget);
  });
  testWidgets(
    'partial targets/rules show loaded vouchers with exports disabled and specific Retry',
    (tester) async {
      repo.targetPages = 2;
      repo.targetGates[1] = Completer();
      repo.rulesFailure = const NetworkFailure();
      await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
      await tester.pumpAndSettle();
      expect(find.byType(VoucherCard), findsOneWidget);
      expect(find.textContaining('Schedules: No connection'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppStrings.share),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, AppStrings.saveImage),
            )
            .onPressed,
        isNull,
      );
      repo.rulesFailure = null;
      await tester.tap(find.text(AppStrings.retry));
      await tester.pumpAndSettle();
      expect(repo.reads.where((read) => read.$1 == 'rules'), hasLength(2));
      repo.targetGates[1]?.complete(samplePage<OfferTarget>([], 1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppStrings.share),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  for (final owner in [true, false]) {
    testWidgets(
      'one voucher per distinct eligible target; warning owner=$owner outside export',
      (tester) async {
        OffersTestAuth.owner = owner;
        repo.targetItems = [
          OffersDto.target({
            ...targetJson(),
            'hasAnotherOfferForSameService': true,
          }),
          OffersDto.target(targetJson(id: 2)),
          OffersDto.target({
            ...targetJson(id: 3),
            'targetType': 'SERVICE',
            'targetNames': ['Hair Cut'],
            'isCombo': true,
          }),
          OffersDto.target({...targetJson(id: 4), 'targetType': 'SERVICE'}),
          OffersDto.target({...targetJson(id: 5), 'targetType': 'OTHER'}),
        ];
        await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.overlapWarning),
          owner ? findsOneWidget : findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(VoucherCard),
            matching: find.text(AppStrings.overlapWarning),
          ),
          findsNothing,
        );
        expect(find.text(AppStrings.allServices), findsNWidgets(2));
        await tester.scrollUntilVisible(find.text('Combo: Hair Cut'), 150);
        expect(find.text('Combo: Hair Cut'), findsOneWidget);
        expect(find.byType(Switch), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final status in ['off', 'expired', 'upcoming', 'invalid', 'unknown']) {
    testWidgets('$status cannot export', (tester) async {
      repo.offerItems = [
        OffersDto.offer({
          ...offerJson(),
          if (status == 'off') 'isActive': false,
          if (status == 'expired') 'endDate': '2026-10-07',
          if (status == 'upcoming') 'startDate': '2026-10-09',
          if (status == 'invalid') 'endDate': null,
          if (status == 'unknown') 'discountType': 'OTHER',
        }),
      ];
      await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, AppStrings.share),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, AppStrings.saveImage),
            )
            .onPressed,
        isNull,
      );
      expect(platform.saves + platform.shares + platform.permissions, 0);
    });
  }
  testWidgets(
    'complete no targets shows explicit empty, not failed-resource empty',
    (tester) async {
      repo.targetItems = [];
      await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noTargets), findsOneWidget);
      repo.targetsFailure = const NetworkFailure();
      await container
          .read(offersControllerProvider.notifier)
          .retry(OffersResource.targets, restart: true);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.noTargets), findsNothing);
    },
  );
  testWidgets('pagination cap is explicit in details and prevents export', (
    tester,
  ) async {
    repo.rulePages = 11;
    await pump(tester, screen: const OfferDetailsScreen(offerId: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.resourceCap), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, AppStrings.share),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, AppStrings.saveImage),
          )
          .onPressed,
      isNull,
    );
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'compact normal phone colored ticket $mode matches reference structure',
      (tester) async {
        tester.view.physicalSize = const Size(398, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, mode: mode);
        await tester.pumpAndSettle();
        final ticket = find.byType(OfferTicket);
        final value = find.byKey(const ValueKey('discount-1'));
        expect(tester.getSize(ticket).height, lessThan(180));
        expect(tester.getSize(value).width, AppTokens.offerTicketValueWidth);
        expect(
          tester.getTopLeft(value).dx,
          lessThan(tester.getTopLeft(find.text('BINGO DISCOUNT')).dx),
        );
        expect(
          tester.getTopLeft(find.text('BINGO DISCOUNT')).dy,
          lessThan(tester.getTopLeft(find.byType(DayCircles)).dy),
        );
        expect(
          find.text('February 17, 2026 – February 26, 2027'),
          findsOneWidget,
        );
        expect(find.byType(Switch), findsNothing);
        expect(find.textContaining('Rule '), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('list/details narrow large text $mode without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, mode: mode);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await pump(
        tester,
        mode: mode,
        screen: const OfferDetailsScreen(offerId: 1),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('real boundary produces PNG at 3x without owner warning', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: RepaintBoundary(
              key: key,
              child: VoucherCard(
                offer: OffersDto.offer(offerJson()),
                target: OffersDto.target(targetJson()),
                shop: 'Fuzion',
                summary: OffersView().schedule(1),
                design: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Uint8List bytes =
        await tester.runAsync(
          () => FlutterVoucherCapture(key, waitForPaint: () async {}).capture(),
        ) ??
        Uint8List(0);
    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final width = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      frame.image.dispose();
      codec.dispose();
      return width;
    });
    expect(width, (320 * AppTokens.voucherPixelRatio).round());
  });
}
