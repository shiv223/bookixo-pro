import 'dart:async';
import 'dart:io';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_controller.dart';
import 'package:bookixo_pro/features/queue/data/mock_queue_repository.dart';
import 'package:bookixo_pro/features/queue/domain/queue_item.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_flow_controller.dart';
import 'package:bookixo_pro/features/queue/presentation/new_booking_screen.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_controller.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_realtime_controller.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_realtime_coordinator.dart';
import 'package:bookixo_pro/features/queue/domain/queue_realtime_repository.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_screen.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fakes.dart';

class FixedMenuController extends MenuController {
  FixedMenuController(this.keys);
  final Set<String> keys;
  @override
  Future<MenuView?> build() async =>
      MenuView(MenuSnapshot(const MenuScope('5', null, 15), keys, testNow));
}

class SampleQueueRepository implements QueueRepository {
  List<QueueItem> items = [];
  final Map<String, int> loadCounts = {};
  AppFailure? failure;
  AppFailure? lookupFailure;
  bool createAllowed = false;
  CustomerLookup? lookupResult;
  final List<String> lookups = [];
  Completer<CustomerLookup?>? lookupGate;
  NewBookingRequest? lastCreateRequest;
  int startCount = 0;
  Completer<List<QueueItem>>? gate;
  @override
  bool get canCreateWalkIn => createAllowed;
  @override
  Future<List<QueueItem>> load(String tab) async {
    loadCounts.update(tab, (count) => count + 1, ifAbsent: () => 1);
    if (failure case final AppFailure error) throw error;
    return await gate?.future ?? items;
  }

  @override
  Future<CustomerLookup?> lookupCustomer(String phoneNumber) async {
    lookups.add(phoneNumber);
    if (lookupFailure case final AppFailure error) throw error;
    return await lookupGate?.future ?? lookupResult;
  }

  @override
  Future<QueueItem> createWalkIn(NewBookingRequest request) async {
    lastCreateRequest = request;
    return QueueItem('new', request.firstName, '', queueNumber: 1);
  }

  @override
  Future<QueueItem> start(String bookingId) async {
    startCount++;
    return const QueueItem(
      'started',
      'Started',
      '',
      status: QueueBookingStatus.inProgress,
    );
  }
}

class QueueTestRealtimeConnection implements QueueRealtimeConnection {
  final StreamController<QueueRealtimeSignal> _signals =
      StreamController<QueueRealtimeSignal>.broadcast(sync: true);
  final List<int> subscriptions = [];
  int disconnects = 0;

  @override
  Stream<QueueRealtimeSignal> get signals => _signals.stream;

  @override
  void connect() {}

  @override
  Future<bool> subscribe(int shopId) async {
    subscriptions.add(shopId);
    return true;
  }

  @override
  Future<bool> unsubscribe(int shopId) async => true;

  @override
  void disconnect() => disconnects++;

  @override
  void dispose() => unawaited(_signals.close());

  void emit(QueueRealtimeSignal signal) => _signals.add(signal);
}

class QueueTestRealtimeRepository implements QueueRealtimeRepository {
  final QueueTestRealtimeConnection connection = QueueTestRealtimeConnection();

  @override
  QueueRealtimeConnection create({
    required String baseUrl,
    required String path,
  }) => connection;
}

void main() {
  for (final employee in [true, false]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'Queue header preserves role actions at 320px, text $scale, employee $employee',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final auth = FakeAuthRepository()
            ..restored = sampleSession(
              groups: [employee ? 'shop_employee' : 'shop_owner'],
            );
          await tester.pumpWidget(
            ProviderScope(
              key: const ValueKey('isolated-header'),
              overrides: [
                selectedShopProvider.overrideWithValue(
                  const Shop(15, 'Salon A'),
                ),
                configProvider.overrideWithValue(
                  AppConfig.parse('https://example.test', debug: true),
                ),
                menuControllerProvider.overrideWith(
                  () => FixedMenuController({'bookings-pending'}),
                ),
                queueRepositoryProvider.overrideWithValue(
                  SampleQueueRepository(),
                ),
                authRepositoryProvider.overrideWithValue(auth),
                shopRepositoryProvider.overrideWithValue(
                  FakeShopRepository()
                    ..result = ShopContext(const [
                      Shop(15, 'Salon A'),
                      Shop(16, 'Salon B'),
                    ], 15),
                ),
                clockProvider.overrideWithValue(FakeClock()),
              ],
              child: MaterialApp(
                theme: AppTheme.forBrightness(Brightness.dark),
                home: const QueueScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final header = tester.widget<AppInnerHeader>(
            find.byType(AppInnerHeader),
          );
          expect(find.text('Operations · SA'), findsOneWidget);
          if (employee) {
            expect(
              find.widgetWithText(OutlinedButton, AppStrings.logout),
              findsOneWidget,
            );
            await tester.tap(find.text(AppStrings.logout));
            await tester.pumpAndSettle();
            expect(auth.logouts, 1);
          }
          // Exercise the actual header at extreme text sizes, independently
          // of the Queue body's existing date/Refresh row layout.
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                selectedShopProvider.overrideWithValue(
                  const Shop(15, 'Salon A'),
                ),
                configProvider.overrideWithValue(
                  AppConfig.parse('https://example.test', debug: true),
                ),
                authRepositoryProvider.overrideWithValue(auth),
                shopRepositoryProvider.overrideWithValue(
                  FakeShopRepository()
                    ..result = ShopContext(const [
                      Shop(15, 'Salon A'),
                      Shop(16, 'Salon B'),
                    ], 15),
                ),
                clockProvider.overrideWithValue(FakeClock()),
              ],
              child: MaterialApp(
                theme: AppTheme.forBrightness(Brightness.dark),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: header,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppInnerHeader), findsOneWidget);
          expect(find.byType(AppInnerHeaderBadge), findsNothing);
          expect(
            find.byTooltip(AppStrings.back),
            employee ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(AppStrings.logout),
            employee ? findsOneWidget : findsNothing,
          );
          expect(
            find.widgetWithText(TextButton, AppStrings.switchSalon),
            findsNothing,
          );
          expect(find.text('owner'), findsNothing);
          expect(find.text('employee'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final pushQueue in [false, true]) {
    testWidgets(
      'Operations has no salon action or username badge and preserves Back '
      'with previous route $pushQueue',
      (tester) async {
        final router = GoRouter(
          initialLocation: pushQueue ? '/previous' : '/queue',
          routes: [
            GoRoute(
              path: '/previous',
              builder: (_, _) => const Scaffold(body: Text('Previous screen')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home fallback')),
            ),
            GoRoute(path: '/queue', builder: (_, _) => const QueueScreen()),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              configProvider.overrideWithValue(
                AppConfig.parse('https://example.test', debug: true),
              ),
              authRepositoryProvider.overrideWithValue(
                FakeAuthRepository()..restored = sampleSession(),
              ),
              clockProvider.overrideWithValue(FakeClock()),
              shopRepositoryProvider.overrideWithValue(
                FakeShopRepository()
                  ..result = ShopContext(const [
                    Shop(15, 'Salon A'),
                    Shop(16, 'Salon B'),
                  ], 15),
              ),
              selectedShopProvider.overrideWithValue(const Shop(15, 'Salon A')),
              menuControllerProvider.overrideWith(
                () => FixedMenuController({'bookings-pending'}),
              ),
              queueRepositoryProvider.overrideWithValue(
                SampleQueueRepository(),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.forBrightness(Brightness.light),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (pushQueue) {
          unawaited(router.push<void>('/queue'));
          await tester.pumpAndSettle();
        }
        final header = find.byType(AppInnerHeader);
        expect(header, findsOneWidget);
        expect(
          find.descendant(of: header, matching: find.text('Operations · SA')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text('owner')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: header,
            matching: find.byType(AppInnerHeaderBadge),
          ),
          findsNothing,
        );
        expect(find.text(AppStrings.logout), findsNothing);
        expect(find.byTooltip(AppStrings.switchSalon), findsNothing);
        await tester.tap(find.byTooltip(AppStrings.back));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          pushQueue ? '/previous' : '/home',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'mock queue and booking operations are deterministic and price-free',
    () async {
      final repository = MockQueueRepository();
      final items = await repository.load('pending');
      expect(items.single.customer, AppStrings.sampleCustomer);
      expect(items.single.status, QueueBookingStatus.pending);
      expect((await repository.load('in-progress')).single.hasServices, isTrue);
      expect(await repository.lookupCustomer('5550001'), isNotNull);
      final created = await repository.createWalkIn(
        const NewBookingRequest(
          phoneNumber: '5550002',
          firstName: 'Alex',
          lastName: 'Sample',
        ),
      );
      expect(
        (await repository.start(created.id)).status,
        QueueBookingStatus.inProgress,
      );
      final model = File('lib/features/queue/domain/queue_item.dart')
          .readAsStringSync();
      expect(
        model,
        isNot(matches(RegExp(r'\b(price|subtotal|discount|amount)\s*;'))),
      );
      final adapter = File('lib/features/queue/data/mock_queue_repository.dart')
          .readAsStringSync();
      expect(adapter, isNot(contains('dio')));
      expect(adapter, isNot(contains('api/')));
    },
  );
  testWidgets('queue handles loading, empty, error Retry and sample success', (
    tester,
  ) async {
    final repository = SampleQueueRepository()..gate = Completer();
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        menuControllerProvider.overrideWith(
          () => FixedMenuController({'bookings-pending'}),
        ),
        menuScopeProvider.overrideWithValue(const MenuScope('5', null, 15)),
        selectedShopProvider.overrideWithValue(const Shop(15, 'Salon')),
        queueRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository()
            ..restored = sampleSession(groups: ['shop_employee']),
        ),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container.read(menuControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          home: const QueueScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.gate?.complete([]);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.queueEmpty), findsOneWidget);
    repository.gate = null;
    repository.failure = const NetworkFailure();
    container.invalidate(queueItemsProvider('pending'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsOneWidget);
    repository.failure = null;
    repository.items = [
      const QueueItem(
        'sample',
        AppStrings.sampleCustomer,
        AppStrings.sampleService,
      ),
    ];
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining(AppStrings.sampleCustomer), findsOneWidget);
    expect(find.text(AppStrings.inProgress), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.text(AppStrings.addWalkIn), findsNothing);
    expect(find.text(AppStrings.logout), findsOneWidget);
    expect(find.byType(AppInnerHeader), findsOneWidget);
    expect(find.byTooltip(AppStrings.back), findsNothing);
    expect(
      tester.getSize(find.byType(SegmentedButton<String>)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    'queue polls until subscription ack and resumes fallback on disconnect',
    (tester) async {
      final repository = SampleQueueRepository();
      final realtime = QueueTestRealtimeRepository();
      final container = ProviderContainer(
        overrides: [
          configProvider.overrideWithValue(
            AppConfig.parse(
              'https://api.example.test',
              debug: true,
              socketBaseUrl: 'https://socket.example.test',
            ),
          ),
          menuControllerProvider.overrideWith(
            () => FixedMenuController({'bookings-pending'}),
          ),
          menuScopeProvider.overrideWithValue(const MenuScope('5', null, 15)),
          selectedShopProvider.overrideWithValue(const Shop(15, 'Salon')),
          queueRepositoryProvider.overrideWithValue(repository),
          queueRealtimeRepositoryProvider.overrideWithValue(realtime),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()
              ..restored = sampleSession(groups: ['shop_employee']),
          ),
          clockProvider.overrideWithValue(FakeClock()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container.read(menuControllerProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.forBrightness(Brightness.light),
            home: const QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initialReads = repository.loadCounts['pending'] ?? 0;
      await tester.pump(queueRefreshInterval);
      await tester.pump();
      expect(repository.loadCounts['pending'], initialReads + 1);
      expect(find.text(AppStrings.queueRealtimeConnecting), findsOneWidget);

      realtime.connection.emit(
        const QueueRealtimeSignal.connection(QueueRealtimeSignalType.connected),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(realtime.connection.subscriptions, [15]);
      expect(find.text(AppStrings.queueRealtimeConnected), findsOneWidget);
      final readsAfterSubscription = repository.loadCounts['pending'] ?? 0;
      await tester.pump(queueRefreshInterval * 2);
      await tester.pump();
      expect(repository.loadCounts['pending'], readsAfterSubscription);

      realtime.connection.emit(
        const QueueRealtimeSignal.connection(
          QueueRealtimeSignalType.disconnected,
        ),
      );
      expect(
        container.read(queueRealtimeCoordinatorProvider).status,
        QueueRealtimeStatus.disconnected,
      );
      await tester.pumpAndSettle();
      expect(
        container.read(queueRealtimeStatusProvider).asData?.value,
        QueueRealtimeStatus.disconnected,
      );
      expect(find.text(AppStrings.queueRealtimeDisconnected), findsOneWidget);
      await tester.pump(queueRefreshInterval);
      await tester.pump();
      expect(repository.loadCounts['pending'], readsAfterSubscription + 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'in-progress booking card opens details without a separate button',
    (tester) async {
      final repository = SampleQueueRepository()
        ..items = [
          const QueueItem(
            'booking-123',
            'Avery Customer',
            'Haircut',
            status: QueueBookingStatus.inProgress,
            assignedToCurrentUser: true,
          ),
        ];
      final router = GoRouter(
        initialLocation: '/queue',
        routes: [
          GoRoute(
            path: '/queue',
            builder: (_, _) =>
                const QueueScreen(requestedTab: QueueTabSelector.inProgress),
          ),
          GoRoute(
            path: '/queue/:bookingId',
            builder: (_, state) =>
                Text('Booking ${state.pathParameters['bookingId']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configProvider.overrideWithValue(
              AppConfig.parse('https://example.test', debug: true),
            ),
            menuControllerProvider.overrideWith(
              () => FixedMenuController({
                'bookings-pending',
                'bookings-in-progress',
              }),
            ),
            queueRepositoryProvider.overrideWithValue(repository),
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository()
                ..restored = sampleSession(groups: ['shop_employee']),
            ),
            clockProvider.overrideWithValue(FakeClock()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.forBrightness(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open booking'), findsNothing);
      await tester.tap(
        find.text(AppStrings.queueCustomer(1, 'Avery Customer')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Booking booking-123'), findsOneWidget);
    },
  );

  testWidgets('owner sees back action and round create button', (tester) async {
    final repository = SampleQueueRepository()..createAllowed = true;
    final container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        menuControllerProvider.overrideWith(
          () => FixedMenuController({'bookings-pending'}),
        ),
        queueRepositoryProvider.overrideWithValue(repository),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository()
            ..restored = sampleSession(groups: ['shop_owner']),
        ),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(menuControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          home: const QueueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.back), findsOneWidget);
    expect(find.byType(AppInnerHeader), findsOneWidget);
    expect(find.text(AppStrings.logout), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip(AppStrings.addWalkIn), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
    'queue refreshes every 15 seconds and when returning foreground',
    (tester) async {
      final repository = SampleQueueRepository();
      final container = ProviderContainer(
        overrides: [
          configProvider.overrideWithValue(
            AppConfig.parse('https://example.test', debug: true),
          ),
          menuControllerProvider.overrideWith(
            () => FixedMenuController({'bookings-pending'}),
          ),
          menuScopeProvider.overrideWithValue(const MenuScope('5', null, 15)),
          selectedShopProvider.overrideWithValue(const Shop(15, 'Salon')),
          queueRepositoryProvider.overrideWithValue(repository),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository()
              ..restored = sampleSession(groups: ['shop_employee']),
          ),
          clockProvider.overrideWithValue(FakeClock()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await container.read(menuControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.forBrightness(Brightness.light),
            home: const QueueScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.loadCounts['pending'], 1);

      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(repository.loadCounts['pending'], 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.loadCounts['pending'], 3);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15));
      expect(repository.loadCounts['pending'], 3);
    },
  );
  test('unpermitted tab provider never calls the queue repository', () async {
    final repository = SampleQueueRepository()..failure = const ServerFailure();
    final container = ProviderContainer(
      overrides: [
        menuControllerProvider.overrideWith(
          () => FixedMenuController({'bookings-pending'}),
        ),
        queueRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(menuControllerProvider.future);
    expect(
      await container.read(queueItemsProvider('in-progress').future),
      isEmpty,
    );
  });

  testWidgets('lookup fills editable existing customer fields on Continue', (
    tester,
  ) async {
    final repository = SampleQueueRepository()
      ..createAllowed = true
      ..lookupResult = const CustomerLookup(
        firstName: 'Morgan',
        lastName: 'Lee',
        gender: 'Female',
      );
    final container = ProviderContainer(
      overrides: [
        queueRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NewBookingScreen()),
        GoRoute(path: '/queue', builder: (_, _) => const Text('Queue page')),
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
    await tester.enterText(find.byType(TextFormField).first, '5551234567');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.customerFound), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      'Morgan',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Changed');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller
          ?.text,
      'Changed',
    );
  });

  testWidgets('failed lookup does not block create and optional start', (
    tester,
  ) async {
    final repository = SampleQueueRepository()
      ..createAllowed = true
      ..lookupFailure = const NetworkFailure();
    final container = ProviderContainer(
      overrides: [
        queueRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const NewBookingScreen()),
        GoRoute(path: '/queue', builder: (_, _) => const Text('Queue page')),
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
    await tester.enterText(find.byType(TextFormField).first, '5551234567');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.lookupFailedCreateAnyway), findsOneWidget);
    expect(find.text(AppStrings.noAccess), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('booking-first-name')),
      'Avery',
    );
    expect(
      tester
          .state<FormFieldState<String>>(
            find.byKey(const ValueKey('booking-first-name')),
          )
          .value,
      'Avery',
    );
    await tester.ensureVisible(find.text(AppStrings.createBooking));
    await tester.tap(find.text(AppStrings.createBooking));
    await tester.pumpAndSettle();
    expect(repository.lastCreateRequest?.firstName, 'Avery');
    expect(repository.startCount, 1);
    expect(router.routeInformationProvider.value.uri.path, '/queue');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['tab'],
      QueueTabSelector.inProgress,
    );
  });

  test('a started walk-in is not re-started by the next new booking', () async {
    final repository = SampleQueueRepository();
    final container = ProviderContainer(
      overrides: [queueRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(bookingFlowControllerProvider.notifier);
    const request = NewBookingRequest(
      phoneNumber: '9000000001',
      firstName: 'A',
      lastName: '',
    );

    expect(
      await controller.createWalkIn(request, startImmediately: true),
      isNotNull,
    );
    expect(
      container.read(bookingFlowControllerProvider).createdBooking,
      isNull,
    );

    await controller.createWalkIn(request, startImmediately: false);
    expect(
      container.read(bookingFlowControllerProvider).createdBooking,
      isNull,
    );

    controller.startNewBooking();
    expect(await controller.startCreatedBooking(), isNull);
    expect(repository.startCount, 1);
  });

  testWidgets('lookup runs once when the phone number reaches 10 digits', (
    tester,
  ) async {
    final repository = SampleQueueRepository()..createAllowed = true;
    final container = ProviderContainer(
      overrides: [
        queueRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          home: const NewBookingScreen(),
        ),
      ),
    );
    final phone = find.byKey(const ValueKey('booking-phone'));

    await tester.enterText(phone, '555123456');
    await tester.pumpAndSettle();
    expect(repository.lookups, isEmpty);
    expect(find.text(AppStrings.newCustomerNotice), findsNothing);

    await tester.enterText(phone, '5551234567');
    await tester.pumpAndSettle();
    expect(repository.lookups, ['5551234567']);
    expect(find.text(AppStrings.newCustomerNotice), findsOneWidget);

    await tester.enterText(phone, '+91 55512 34567');
    await tester.pumpAndSettle();
    expect(repository.lookups, ['5551234567']);

    await tester.enterText(phone, '555123456');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.newCustomerNotice), findsNothing);

    await tester.enterText(phone, '5551234568');
    await tester.pumpAndSettle();
    expect(repository.lookups, ['5551234567', '5551234568']);
  });

  testWidgets('a failed automatic lookup can be retried', (tester) async {
    final repository = SampleQueueRepository()
      ..createAllowed = true
      ..lookupFailure = const NetworkFailure();
    final container = ProviderContainer(
      overrides: [
        queueRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(FakeClock()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          home: const NewBookingScreen(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('booking-phone')),
      '5551234567',
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.lookupFailedCreateAnyway), findsOneWidget);

    repository.lookupFailure = null;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(repository.lookups, ['5551234567', '5551234567']);
    expect(find.text(AppStrings.newCustomerNotice), findsOneWidget);
  });

  test('an older lookup response cannot overwrite a newer one', () async {
    final repository = SampleQueueRepository();
    final container = ProviderContainer(
      overrides: [queueRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(bookingFlowControllerProvider.notifier);
    final slow = Completer<CustomerLookup?>();
    repository.lookupGate = slow;
    final first = controller.lookupCustomer('5551234567');

    repository.lookupGate = null;
    await controller.lookupCustomer('5551234568');
    expect(
      container.read(bookingFlowControllerProvider).lookupStatus,
      CustomerLookupStatus.newCustomer,
    );

    slow.complete(const CustomerLookup(firstName: 'Stale'));
    await first;
    final flow = container.read(bookingFlowControllerProvider);
    expect(flow.lookupStatus, CustomerLookupStatus.newCustomer);
    expect(flow.customer, isNull);
  });
}
