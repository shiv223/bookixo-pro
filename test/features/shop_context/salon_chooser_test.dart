import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';

import 'package:bookixo_pro/app.dart';
import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/routing/app_router.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:bookixo_pro/features/queue/data/mock_booking_repository.dart';
import 'package:bookixo_pro/features/queue/data/mock_queue_repository.dart';
import 'package:bookixo_pro/features/queue/domain/booking_workspace.dart';
import 'package:bookixo_pro/features/queue/domain/shop_features_repository.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_workspace_controller.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_selection_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_switch_guard.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../home/logo_controller_test.dart' show FakeLogoRepository;
import '../menu/controller_test.dart' show FakeMenuRepository;
import 'salon_selection_test.dart' show MemorySalonPreferences;

class BranchMenu extends FakeMenuRepository {
  BranchMenu(super.store, super.clock);
  final branches = <int, Set<String>>{
    15: {'bookings-pending', 'bookings-in-progress'},
    16: {},
  };
  bool fail = false;
  @override
  Future<MenuSnapshot> fetch(MenuScope scope) async {
    calls++;
    if (fail) throw const NetworkFailure();
    return MenuSnapshot(scope, branches[scope.shopId] ?? {}, clock.now());
  }
}

class BranchFeatures implements ShopFeaturesRepository {
  final reads = <int>[];
  @override
  Future<Set<String>> loadEnabledFeatures(int shopId) async {
    reads.add(shopId);
    return shopId == 15 ? {'SHOP_BOOKINGS_CREATE'} : {};
  }
}

class GatedBooking extends MockBookingRepository {
  Completer<void>? saveGate;
  Completer<void>? paymentGate;
  Completer<void>? discardGate;
  int saves = 0;
  int payments = 0;
  int discards = 0;
  @override
  Future<void> discardDraft({
    required String bookingId,
    required int expectedRevision,
  }) async {
    discards++;
    await discardGate?.future;
    return super.discardDraft(
      bookingId: bookingId,
      expectedRevision: expectedRevision,
    );
  }

  @override
  Future<BookingDraft> saveOwnerDraft({
    required String bookingId,
    required int expectedRevision,
    required List<BookingDraftLine> lines,
    BookingPaymentDraft? payment,
  }) async {
    saves++;
    await saveGate?.future;
    return super.saveOwnerDraft(
      bookingId: bookingId,
      expectedRevision: expectedRevision,
      lines: lines,
      payment: payment,
    );
  }

  @override
  Future<BookingCompletionResult> complete({
    required String bookingId,
    required int expectedRevision,
  }) async {
    payments++;
    await paymentGate?.future;
    return super.complete(
      bookingId: bookingId,
      expectedRevision: expectedRevision,
    );
  }
}

void main() {
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late BranchMenu menu;
  late BranchFeatures features;
  late GatedBooking booking;
  setUp(() {
    auth = FakeAuthRepository()..restored = sampleSession();
    final clock = FakeClock();
    final cache = MenuCacheStore(MemoryBackend());
    menu = BranchMenu(cache, clock);
    features = BranchFeatures();
    booking = GatedBooking();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        clockProvider.overrideWithValue(clock),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(
          FakeShopRepository()
            ..result = ShopContext(const [
              Shop(15, 'Salon A'),
              Shop(16, 'Salon B'),
            ], 15),
        ),
        salonPreferenceRepositoryProvider.overrideWithValue(
          MemorySalonPreferences(),
        ),
        menuCacheStoreProvider.overrideWithValue(cache),
        menuRepositoryProvider.overrideWithValue(menu),
        shopLogoRepositoryProvider.overrideWithValue(FakeLogoRepository()),
        shopFeaturesRepositoryProvider.overrideWithValue(features),
        queueRepositoryProvider.overrideWith((ref) {
          ref.watch(scopeRevisionProvider);
          return MockQueueRepository();
        }),
        bookingRepositoryProvider.overrideWithValue(booking),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BookixoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseB(WidgetTester tester) async {
    final homeControl = find.byKey(const ValueKey('home-salon-switch'));
    await tester.tap(
      homeControl.evaluate().isNotEmpty
          ? homeControl
          : find.byTooltip(AppStrings.switchSalon).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salon B'));
    await tester.pumpAndSettle();
  }

  String route() =>
      container.read(routerProvider).routeInformationProvider.value.uri.path;

  testWidgets(
    'Home chooser scopes feature/menu/cache; no-access has no switch',
    (tester) async {
      menu.branches[15] = {'shopdashboard'};
      await pump(tester);
      expect(route(), '/home');
      expect(find.byKey(const ValueKey('home-salon-switch')), findsOneWidget);
      await container.read(enabledShopFeaturesProvider.future);
      expect(features.reads, contains(15));
      final previousQueue = container.read(queueRepositoryProvider);
      await chooseB(tester);
      expect(route(), '/no-access');
      expect(container.read(selectedShopProvider)?.id, 16);
      expect(
        container.read(menuControllerProvider).requireValue?.projection.tiles,
        isEmpty,
      );
      expect(await container.read(enabledShopFeaturesProvider.future), isEmpty);
      expect(features.reads, contains(16));
      expect(
        container.read(queueRepositoryProvider),
        isNot(same(previousQueue)),
      );
      expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(container.read(salonSelectionProvider.notifier).select(15), true);
      await tester.pumpAndSettle();
      expect(route(), '/home');
      expect(
        container
            .read(menuControllerProvider)
            .requireValue
            ?.snapshot
            .scope
            .shopId,
        15,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('owner chooser on Home', (tester) async {
    menu.branches[15] = {'shopdashboard', 'bookings-pending'};
    await pump(tester);
    expect(route(), '/home');
    expect(find.byKey(const ValueKey('home-salon-switch')), findsOneWidget);
    await chooseB(tester);
    expect(route(), '/no-access');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'same-permission branch switch clears pushed booking and pageless dialog',
    (tester) async {
      menu.branches[16] = {'bookings-pending', 'bookings-in-progress'};
      await pump(tester);
      final router = container.read(routerProvider);
      router.push('/queue/sample-in-progress');
      await tester.pumpAndSettle();
      expect(router.canPop(), true);
      final dialog = showDialog<void>(
        context: tester.element(find.text('Booking details · SA')),
        builder: (_) => const AlertDialog(content: Text('Old branch dialog')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old branch dialog'), findsOneWidget);
      expect(container.read(salonSelectionProvider.notifier).select(16), true);
      await tester.pumpAndSettle();
      await dialog;
      expect(route(), '/queue');
      expect(router.canPop(), false);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Booking details · SA'), findsNothing);
      expect(
        container
            .read(menuControllerProvider)
            .requireValue
            ?.snapshot
            .scope
            .shopId,
        16,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('menu-error has Retry but no owner switch or logout', (
    tester,
  ) async {
    menu.fail = true;
    await pump(tester);
    expect(route(), '/menu');
    expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
    expect(find.byIcon(Icons.storefront_outlined), findsNothing);
    expect(find.text(AppStrings.logout), findsNothing);
    expect(find.text('Bookixo Pro · SA'), findsOneWidget);
    menu.fail = false;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(route(), '/queue');
    expect(tester.takeException(), isNull);
  });
  testWidgets('employee never gets chooser or owner payment UI', (
    tester,
  ) async {
    auth.restored = sampleSession(groups: ['shop_employee']);
    await pump(tester);
    expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
    container.read(routerProvider).go('/queue/sample-in-progress');
    await tester.pumpAndSettle();
    expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
    expect(find.text(AppStrings.paymentMode), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
  });
  testWidgets(
    'new booking has no switch, retains input and keeps selection guard',
    (tester) async {
      await pump(tester);
      container.read(routerProvider).go('/queue/new');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('booking-phone')),
        '987',
      );
      expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(find.text('New booking · SA'), findsOneWidget);
      expect(container.read(salonSelectionProvider.notifier).select(16), false);
      expect(find.text('987'), findsOneWidget);
      expect(container.read(selectedShopProvider)?.id, 15);
      expect(
        container
            .read(salonSelectionProvider.notifier)
            .select(16, discardConfirmed: true),
        true,
      );
      await tester.pumpAndSettle();
      expect(route(), '/no-access');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('987'), findsNothing);
      expect(container.read(routerProvider).canPop(), false);
    },
  );
  testWidgets(
    'booking services have no switch; dirty and inflight guards remain',
    (tester) async {
      await pump(tester);
      container.read(routerProvider).go('/queue/sample-in-progress');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.ownerEditServices));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blow dry'));
      await tester.pumpAndSettle();
      expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(find.text('Booking details · SA'), findsOneWidget);
      expect(container.read(salonSelectionProvider.notifier).select(16), false);
      final gate = Completer<void>();
      booking.saveGate = gate;
      await tester.tap(find.text(AppStrings.saveChanges));
      await tester.pump();
      expect(booking.saves, 1);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(
        container
            .read(salonSelectionProvider.notifier)
            .select(16, discardConfirmed: true),
        false,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(container.read(salonSwitchGuardProvider).busy, false);
      await tester.tap(find.text(AppStrings.ownerEditServices));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facial'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(salonSelectionProvider.notifier)
            .select(16, discardConfirmed: true),
        true,
      );
      await tester.pumpAndSettle();
      expect(route(), '/no-access');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'payment has no switch; inflight payment cannot switch or replay',
    (tester) async {
      await pump(tester);
      container.read(routerProvider).go('/queue/sample-in-progress');
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.cash));
      await tester.pumpAndSettle();
      expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
      expect(find.byIcon(Icons.storefront_outlined), findsNothing);
      expect(container.read(salonSelectionProvider.notifier).select(16), false);
      final gate = Completer<void>();
      booking.paymentGate = gate;
      await tester.tap(find.text(AppStrings.completePayment));
      await tester.pump();
      await tester.pump();
      expect(booking.payments, 1);
      expect(container.read(salonSwitchGuardProvider).busy, true);
      expect(
        container
            .read(salonSelectionProvider.notifier)
            .select(16, discardConfirmed: true),
        false,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(booking.payments, 1);
      expect(container.read(salonSwitchGuardProvider).busy, false);
    },
  );
  testWidgets(
    'confirmed draft discard blocks salon switch until request settles',
    (tester) async {
      await pump(tester);
      container.read(routerProvider).go('/queue/sample-in-progress');
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      booking.discardGate = gate;
      await tester.tap(find.text(AppStrings.discardDraft));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.discardDraft),
      );
      await tester.pump();
      expect(booking.discards, 1);
      expect(container.read(salonSwitchGuardProvider).busy, true);
      expect(
        container
            .read(salonSelectionProvider.notifier)
            .select(16, discardConfirmed: true),
        false,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(container.read(salonSwitchGuardProvider).busy, false);
      expect(booking.discards, 1);
    },
  );
}
