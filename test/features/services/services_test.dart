import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/features/menu/presentation/destination_scope_provider.dart';
import 'package:bookixo_pro/features/queue/data/mock_booking_repository.dart';
import 'package:bookixo_pro/features/queue/domain/booking_service_group.dart';
import 'package:bookixo_pro/features/queue/domain/booking_workspace.dart';
import 'package:bookixo_pro/features/queue/domain/service_catalogue.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_workspace_controller.dart';
import 'package:bookixo_pro/features/services/presentation/services_controller.dart';
import 'package:bookixo_pro/features/services/presentation/services_screen.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_users/controller_screen_test.dart'
    show directoryScope, directoryScopeProvider;

const catalogue = [
  BookingService(id: 'child', name: 'Trim', parentId: 'parent', usual: true),
  BookingService(id: 'parent', name: 'Hair', isBookable: false),
  BookingService(id: 'root', name: 'Massage'),
  BookingService(id: 'orphan', name: 'Orphan', parentId: 'absent'),
  BookingService(id: 'self', name: 'Self', parentId: 'self'),
  BookingService(id: 'a', name: 'Cycle A', parentId: 'b'),
  BookingService(id: 'b', name: 'Cycle B', parentId: 'a'),
  BookingService(id: 'descendant', name: 'Cycle descendant', parentId: 'a'),
];

class FakeCatalogueRepository extends MockBookingRepository {
  Completer<List<BookingService>>? gate;
  AppFailure? failure;
  List<BookingService> rows = catalogue;
  @override
  Future<List<BookingService>> loadServices() async {
    if (failure case final failure?) throw failure;
    return gate?.future ?? rows;
  }
}

void main() {
  test(
    'parent precedes children; ungrouped/orphan/cyclic rows appear once',
    () {
      final rows = ServiceCatalogue(catalogue).rows;
      expect(rows.map((row) => row.service.id), [
        'parent',
        'child',
        'root',
        'orphan',
        'self',
        'a',
        'b',
        'descendant',
      ]);
      expect(rows.map((row) => row.depth), [0, 1, 0, 0, 0, 0, 0, 0]);
      expect(rows.first.isHeading, isTrue);
      expect(rows[1].service.usual, isTrue);
      final pickerGroups = BookingServiceGroup.filter(
        catalogue,
        usual: false,
        search: 'cycle',
      );
      expect(pickerGroups.single.name, isNull);
      expect(pickerGroups.single.services.length, 3);
    },
  );
  test('bookable parents and nested category descendants stay visible', () {
    final rows = ServiceCatalogue(const [
      BookingService(id: '1', name: 'Category'),
      BookingService(
        id: '2',
        name: 'Subcategory',
        parentId: '1',
        isBookable: false,
      ),
      BookingService(id: '3', name: 'Option', parentId: '2'),
    ]).rows;
    expect(rows.map((row) => row.depth), [0, 1, 2]);
    expect(rows.map((row) => row.isHeading), [true, true, false]);
  });
  test('an orphan category still heads its own valid children', () {
    final rows = ServiceCatalogue(const [
      BookingService(id: '1', name: 'Orphan category', parentId: 'missing'),
      BookingService(id: '2', name: 'Child', parentId: '1'),
    ]).rows;
    expect(rows.map((row) => row.depth), [0, 1]);
    expect(rows.first.isHeading, isTrue);
  });
  test('late catalogue load cannot replace a new scope response', () async {
    final repo = FakeCatalogueRepository();
    final gate = Completer<List<BookingService>>();
    repo.gate = gate;
    final scoped = ProviderContainer(
      overrides: [
        destinationScopeProvider('shop-services-list')
            .overrideWith((ref) => ref.watch(directoryScopeProvider)),
        bookingRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(scoped.dispose);
    final listener = scoped.listen(servicesCatalogueProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    repo.gate = null;
    repo.rows = const [BookingService(id: 'new', name: 'New scope service')];
    scoped.read(directoryScopeProvider.notifier).replace((
      menu: directoryScope.menu,
      revision: 3,
    ));
    final current = await scoped.read(servicesCatalogueProvider.future);
    gate.complete(catalogue);
    await Future<void>.delayed(Duration.zero);
    expect(current.single.service.id, 'new');
    expect(
      scoped.read(servicesCatalogueProvider).asData?.value.single.service.id,
      'new',
    );
    listener.close();
  });

  late ProviderContainer container;
  late FakeCatalogueRepository repo;
  setUp(() {
    repo = FakeCatalogueRepository();
    container = ProviderContainer(
      overrides: [
        destinationScopeProvider('shop-services-list')
            .overrideWithValue(directoryScope),
        bookingRepositoryProvider.overrideWithValue(repo),
        selectedShopProvider.overrideWithValue(const Shop(15, 'Example salon')),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(Brightness.light),
          home: const ServicesScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loading, error+Retry and empty states reuse repository', (
    tester,
  ) async {
    final gate = Completer<List<BookingService>>();
    repo.gate = gate;
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.completeError(const NetworkFailure(), StackTrace.current);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsOneWidget);
    repo.gate = null;
    repo.rows = [];
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.catalogueEmpty), findsOneWidget);
  });
  testWidgets(
    'catalogue clearly displays categories before children without actions/prices',
    (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.text('Hair'), findsOneWidget);
      expect(find.text('Trim'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Hair')).dy,
        lessThan(tester.getTopLeft(find.text('Trim')).dy),
      );
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('no permission never starts catalogue transport', () async {
    final denied = ProviderContainer(
      overrides: [
        destinationScopeProvider('shop-services-list').overrideWithValue(null),
        bookingRepositoryProvider.overrideWith(
          (_) => throw StateError('must not read'),
        ),
      ],
    );
    addTearDown(denied.dispose);
    expect(await denied.read(servicesCatalogueProvider.future), isEmpty);
  });
}
