import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/routing/menu_route_policy.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_models.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_controller.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_projection.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';

final _testAccessProvider = NotifierProvider<_TestAccess, DashboardAccess?>(
  _TestAccess.new,
);

class _TestAccess extends Notifier<DashboardAccess?> {
  @override
  DashboardAccess? build() => _allowed();

  void replace(DashboardAccess? value) => state = value;
}

DashboardAccess _allowed({
  Set<String> features = const {'shopdashboard'},
  int ownership = 1,
}) {
  final scope = MenuScope('account-1', 'session-1', 5);
  return (
    scope: DashboardScope(menu: scope, ownership: ownership),
    features: features,
  );
}

class _FakeDashboardRepository implements DashboardRepository {
  int bookingCalls = 0;
  int orderCalls = 0;
  int staffCalls = 0;
  int statusCalls = 0;
  int inventoryCalls = 0;
  int walletCalls = 0;
  int membershipCalls = 0;
  bool failStatusOnce = false;
  final List<Completer<DashboardRows<BookingReportRow>>> staleBookings = [];

  @override
  Future<DashboardRows<BookingReportRow>> bookings(
    int shopId,
    DateWindow window,
  ) async {
    bookingCalls++;
    if (bookingCalls <= 2) {
      final completer = Completer<DashboardRows<BookingReportRow>>();
      staleBookings.add(completer);
      return completer.future;
    }
    return DashboardRows([
      BookingReportRow(
        bookingId: bookingCalls,
        bookingDate: window.start,
        finalAmount: 100,
        remainingAmountPaid: 80,
        walletCreditUsed: 20,
        paymentMode: 'UPI',
      ),
    ]);
  }

  @override
  Future<DashboardRows<ProductOrderRow>> orders(
    int shopId,
    DateWindow window,
  ) async {
    orderCalls++;
    return DashboardRows([]);
  }

  @override
  Future<DashboardRows<AssigneeServiceRow>> staffServices(
    int shopId,
    DateWindow window,
  ) async {
    staffCalls++;
    return DashboardRows([]);
  }

  @override
  Future<DashboardRows<BookingStatusRow>> statuses(
    int shopId,
    DateWindow window,
  ) async {
    statusCalls++;
    if (failStatusOnce) {
      failStatusOnce = false;
      throw const NetworkFailure();
    }
    return DashboardRows([]);
  }

  @override
  Future<DashboardRows<InventoryProduct>> inventory(int shopId) async {
    inventoryCalls++;
    return DashboardRows([]);
  }

  @override
  Future<DashboardRows<WalletPurchaseRow>> walletPurchases(
    int shopId,
    DateWindow window,
  ) async {
    walletCalls++;
    return DashboardRows([]);
  }

  @override
  Future<DashboardRows<MembershipSaleRow>> membershipSales(
    int shopId,
    DateWindow window,
  ) async {
    membershipCalls++;
    return DashboardRows([]);
  }
}

void main() {
  test(
    'rapid A B A switch rejects old dashboard responses in identical scope',
    () async {
      final repository = _FakeDashboardRepository();
      final container = _container(repository);
      final subscription = container.listen(
        dashboardControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);
      await _waitFor(() => repository.staleBookings.length == 2);
      final revision = container.read(salonSwitchRevisionProvider.notifier);
      revision.advance();
      revision.advance();
      await _waitFor(() => repository.bookingCalls >= 4);
      for (final gate in repository.staleBookings) {
        gate.complete(
          DashboardRows([
            BookingReportRow(
              bookingId: 999,
              bookingDate: DateTime(2026, 10, 8),
              finalAmount: 999999,
              remainingAmountPaid: 999999,
              walletCreditUsed: 0,
              paymentMode: 'CASH',
            ),
          ]),
        );
      }
      await _waitFor(
        () =>
            container
                .read(dashboardControllerProvider)
                .asData
                ?.value
                ?.rows<BookingReportRow>(DashboardResource.bookings) !=
            null,
      );
      expect(
        container
            .read(dashboardControllerProvider)
            .asData
            ?.value
            ?.rows<BookingReportRow>(DashboardResource.bookings)
            ?.any((row) => row.bookingId == 999),
        false,
      );
    },
  );
  test(
    'loads upper resources first and leaves reports lazy and feature-gated',
    () async {
      final repository = _FakeDashboardRepository();
      final container = _container(repository);
      final subscription = container.listen(
        dashboardControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);

      await _waitFor(() => repository.staffCalls > 0);
      expect(repository.statusCalls, 0);
      expect(repository.inventoryCalls, 0);
      expect(repository.walletCalls, 0);
      expect(repository.membershipCalls, 0);

      await container
          .read(dashboardControllerProvider.notifier)
          .load(DashboardResource.statuses);
      await container
          .read(dashboardControllerProvider.notifier)
          .load(DashboardResource.inventory);
      await container
          .read(dashboardControllerProvider.notifier)
          .load(DashboardResource.walletPurchases);
      expect(repository.statusCalls, 1);
      expect(repository.inventoryCalls, 1);
      expect(repository.walletCalls, 0);
    },
  );

  test(
    'failed lower resource is isolated and retry clears only its failure',
    () async {
      final repository = _FakeDashboardRepository()..failStatusOnce = true;
      final container = _container(repository);
      final subscription = container.listen(
        dashboardControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);
      await _waitFor(() => repository.staffCalls > 0);

      final controller = container.read(dashboardControllerProvider.notifier);
      await controller.load(DashboardResource.statuses);
      var view = container.read(dashboardControllerProvider).asData?.value;
      expect(
        view?.resource(DashboardResource.statuses).failure,
        isA<NetworkFailure>(),
      );
      expect(
        view?.rows<AssigneeServiceRow>(DashboardResource.staffServices),
        isNotNull,
      );

      await controller.retry(DashboardResource.statuses);
      view = container.read(dashboardControllerProvider).asData?.value;
      expect(view?.resource(DashboardResource.statuses).failure, isNull);
      expect(repository.statusCalls, 2);
    },
  );

  test(
    'range change and permission revocation reject stale responses',
    () async {
      final repository = _FakeDashboardRepository();
      final container = _container(repository);
      final subscription = container.listen(
        dashboardControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.dispose);
      await _waitFor(() => repository.staleBookings.length == 2);

      container
          .read(dashboardRangeProvider.notifier)
          .select(DashboardRange.sevenDays);
      await _waitFor(() {
        final rows = container
            .read(dashboardControllerProvider)
            .asData
            ?.value
            ?.rows<BookingReportRow>(DashboardResource.bookings);
        return rows != null;
      });
      final freshDate = container
          .read(dashboardControllerProvider)
          .asData!
          .value!
          .rows<BookingReportRow>(DashboardResource.bookings)!
          .single
          .bookingDate;

      for (final completer in repository.staleBookings) {
        completer.complete(DashboardRows([]));
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final stillFresh = container
          .read(dashboardControllerProvider)
          .asData!
          .value!
          .rows<BookingReportRow>(DashboardResource.bookings)!
          .single
          .bookingDate;
      expect(stillFresh, freshDate);

      container.read(_testAccessProvider.notifier).replace(null);
      await _waitFor(
        () => container.read(dashboardControllerProvider).asData?.value == null,
      );
      expect(container.read(dashboardControllerProvider).asData?.value, isNull);
    },
  );

  test('dashboard child routes inherit exact centralized menu access', () {
    final allowed = MenuProjection({'shopdashboard'});
    final denied = MenuProjection({'bookings-pending'});

    expect(
      MenuRoutePolicy.redirect(Uri.parse('/dashboard/staff/2'), allowed),
      isNull,
    );
    expect(
      MenuRoutePolicy.redirect(Uri.parse('/dashboard/low-stock'), denied),
      '/queue',
    );
  });
}

ProviderContainer _container(_FakeDashboardRepository repository) =>
    ProviderContainer(
      overrides: [
        dashboardAccessProvider.overrideWith(
          (ref) => ref.watch(_testAccessProvider),
        ),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
    );

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Timed out waiting for dashboard state.');
}
