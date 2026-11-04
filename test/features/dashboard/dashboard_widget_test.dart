import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_tokens.dart';
import 'package:bookixo_pro/core/widgets/app_inner_header.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_widgets.dart';
import 'package:bookixo_pro/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_controller.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_models.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';

import '../../support/fakes.dart';
import 'dashboard_backend_fixtures.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('payment segments have painted geometry in $brightness', (
      tester,
    ) async {
      await _pumpChart(
        tester,
        block: DashboardBlock.paymentModes,
        brightness: brightness,
        bookings: [
          _paymentRow(1, 'Cash', 600),
          _paymentRow(2, 'UPI', 300),
          _paymentRow(3, 'Card', 100),
        ],
      );
      _expectSegments(tester, [
        (color: AppTokens.dashboardCash, fraction: .6),
        (color: AppTokens.primary, fraction: .3),
        (color: AppTokens.dashboardCard, fraction: .1),
      ]);
      expect(find.text('Cash ₹600'), findsOneWidget);
      expect(find.text('UPI ₹300'), findsOneWidget);
      expect(find.text('Card ₹100'), findsOneWidget);
    });

    testWidgets('appointment segments have painted geometry in $brightness', (
      tester,
    ) async {
      await _pumpChart(
        tester,
        block: DashboardBlock.appointments,
        brightness: brightness,
        statuses: [
          for (var i = 0; i < 3; i++) _statusRow(i, 'COMPLETED'),
          for (var i = 3; i < 5; i++) _statusRow(i, 'PENDING'),
          _statusRow(5, 'IN_PROGRESS'),
          _statusRow(6, 'CONFIRMED'),
          _statusRow(7, 'CANCELLED'),
          _statusRow(8, 'REJECTED'),
          _statusRow(9, 'CUSTOM'),
        ],
      );
      _expectSegments(tester, [
        (color: AppTokens.dashboardCompleted, fraction: .3),
        (color: AppTokens.dashboardPending, fraction: .2),
        (color: AppTokens.primary, fraction: .1),
        (color: AppTokens.dashboardOther, fraction: .1),
        (color: AppTokens.dashboardCancelled, fraction: .1),
        (color: AppTokens.dashboardCancelled, fraction: .1),
        (color: AppTokens.dashboardOther, fraction: .1),
      ]);
      for (final label in [
        'Completed: 3',
        'Pending: 2',
        'In progress: 1',
        'Confirmed: 1',
        'Cancelled: 1',
        'No Show: 1',
        'CUSTOM: 1',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  }

  testWidgets('zero payment modes take no width and keep the legend', (
    tester,
  ) async {
    await _pumpChart(
      tester,
      block: DashboardBlock.paymentModes,
      bookings: [
        _paymentRow(1, 'Cash', 600),
        _paymentRow(2, 'UPI', 0),
        _paymentRow(3, 'Card', 0),
      ],
    );
    _expectSegments(tester, [(color: AppTokens.dashboardCash, fraction: 1)]);
    expect(find.text('UPI ₹0'), findsOneWidget);
    expect(find.text('Card ₹0'), findsOneWidget);
  });

  testWidgets('absent appointment statuses take no width', (tester) async {
    await _pumpChart(
      tester,
      block: DashboardBlock.appointments,
      statuses: [_statusRow(1, 'PENDING')],
    );
    _expectSegments(tester, [(color: AppTokens.dashboardPending, fraction: 1)]);
    expect(find.text('Pending: 1'), findsOneWidget);
    expect(find.byType(StatusCount), findsOneWidget);
  });

  for (final block in [
    DashboardBlock.paymentModes,
    DashboardBlock.appointments,
  ]) {
    testWidgets('$block empty data renders no segments', (tester) async {
      await _pumpChart(tester, block: block);
      expect(_segments(), findsNothing);
      expect(find.text(AppStrings.dashboardNoSales), findsOneWidget);
    });
  }

  testWidgets(
    'actual backend report contracts render summary, not load failure',
    (tester) async {
      final adapter = StubAdapter(
        (request) => (
          status: 200,
          body: backendReport(
            request.path.contains('/orders/')
                ? [backendOrderRow]
                : request.path.contains('/assignee-performance/')
                ? [backendAssigneeRow]
                : [backendBookingRow],
          ),
        ),
      );
      final client = stubClient(adapter);
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(
              DashboardRepositoryImpl(client),
            ),
            dashboardAccessProvider.overrideWithValue((
              scope: const DashboardScope(
                menu: MenuScope('synthetic', 'session', 5),
                ownership: 1,
              ),
              features: const {'shopdashboard'},
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final view = ref
                      .watch(dashboardControllerProvider)
                      .asData
                      ?.value;
                  if (view == null) return const SizedBox.shrink();
                  return DashboardBlockView(
                    block: DashboardBlock.hero,
                    view: view,
                    controller: ref.read(dashboardControllerProvider.notifier),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.dashboardNetRevenue), findsOneWidget);
      expect(find.text('₹876'), findsOneWidget);
      expect(find.text(AppStrings.dashboardUnavailable), findsNothing);
      expect(tester.takeException(), isNull);
      expect(adapter.requests, hasLength(5));
    },
  );

  testWidgets(
    'range selector and header remain readable in dark compact layout',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: Column(
                children: [
                  AppInnerHeader(title: AppStrings.dashboard),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: DashboardRangeControl(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.dashboard), findsOneWidget);
      expect(find.text(AppStrings.dashboardToday), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, Object?> _paymentRow(int id, String mode, double amount) => {
  ...backendBookingRow,
  'bookingId': id,
  'paymentMode': mode,
  'remainingAmountPaid': amount,
};

Map<String, Object?> _statusRow(int id, String status) => {
  'bookingId': id + 1,
  'bookingDate': '2026-10-10',
  'status': status,
};

Future<void> _pumpChart(
  WidgetTester tester, {
  required DashboardBlock block,
  Brightness brightness = Brightness.light,
  List<Object?> bookings = const [],
  List<Object?> statuses = const [],
}) async {
  final adapter = StubAdapter(
    (request) => (
      status: 200,
      body: backendReport(
        request.path.contains('/booking-status-rows/')
            ? statuses
            : request.path.contains('/bookings/')
            ? bookings
            : [],
      ),
    ),
  );
  final client = stubClient(adapter);
  addTearDown(client.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          DashboardRepositoryImpl(client),
        ),
        dashboardAccessProvider.overrideWithValue((
          scope: const DashboardScope(
            menu: MenuScope('synthetic', 'session', 5),
            ownership: 1,
          ),
          features: const {'shopdashboard'},
        )),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final view = ref.watch(dashboardControllerProvider).asData?.value;
              if (view == null) return const SizedBox.shrink();
              return DashboardBlockView(
                block: block,
                view: view,
                controller: ref.read(dashboardControllerProvider.notifier),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (block == DashboardBlock.appointments) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardBlockView)),
    );
    final load = container
        .read(dashboardControllerProvider.notifier)
        .load(DashboardResource.statuses);
    await tester.pumpAndSettle();
    await load;
  }
  expect(tester.takeException(), isNull);
}

Finder _segments() => find.descendant(
  of: find.byType(ClipRRect),
  matching: find.byType(ColoredBox),
);

void _expectSegments(
  WidgetTester tester,
  List<({Color color, double fraction})> expected,
) {
  final segments = _segments();
  expect(segments, findsNWidgets(expected.length));
  final track = tester.getRect(find.byType(ClipRRect));
  expect(track.width, greaterThan(0));
  expect(track.height, 14);
  expect(
    tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
    BorderRadius.circular(8),
  );
  var left = track.left;
  for (var i = 0; i < expected.length; i++) {
    final segment = segments.at(i);
    final rect = tester.getRect(segment);
    expect(tester.widget<ColoredBox>(segment).color, expected[i].color);
    expect(rect.width, greaterThan(0));
    expect(rect.height, 14);
    expect(rect.width / track.width, closeTo(expected[i].fraction, .001));
    expect(rect.left, closeTo(left, .001));
    expect(rect.top, track.top);
    left = rect.right;
  }
  expect(left, closeTo(track.right, .001));
}
