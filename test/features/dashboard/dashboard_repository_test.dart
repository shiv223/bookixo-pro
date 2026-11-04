import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/dashboard/data/dashboard_dto.dart';
import 'package:bookixo_pro/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_analytics.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'dashboard_backend_fixtures.dart';

void main() {
  final window = DateWindow(
    DateTime.utc(2026, 10, 10),
    DateTime.utc(2026, 10, 10),
  );

  test(
    'served list metadata and nullable labels load through the live repository',
    () async {
      final adapter = StubAdapter(
        (request) => (
          status: 200,
          body: backendReport(
            request.path.contains('/orders/')
                ? [backendOrderRow]
                : request.path.contains('/assignee-performance/')
                ? [
                    backendAssigneeRow,
                    backendAssigneeRow,
                    {
                      ...backendAssigneeRow,
                      'catalogServices': 'Second Service',
                      'servicePrice': 200,
                    },
                  ]
                : [backendBookingRow],
          ),
        ),
      );
      final client = stubClient(adapter);
      addTearDown(client.close);
      final repository = DashboardRepositoryImpl(client);
      final bookings = await repository.bookings(5, window);
      final orders = await repository.orders(5, window);
      final staff = await repository.staffServices(5, window);

      expect(bookings.rows.single.paymentMode, isEmpty);
      expect(
        DashboardAnalytics.sumBookings(
              bookings.rows,
              (row) => row.remainingAmountPaid,
            ) +
            DashboardAnalytics.sumOrders(orders.rows),
        875.75,
      );
      expect(staff.rows.first.displayName, 'Synthetic Staff');
      expect(DashboardAnalytics.topStaff(staff.rows).single.revenue, 1200.5);
      expect(DashboardAnalytics.topStaff(staff.rows).single.clients, 1);
      expect(DashboardAnalytics.topServices(staff.rows).first.amount, 1000.5);
      expect(adapter.requests.map((r) => r.path), [
        'api/public/bookings/audit/booking-metrics/tabularview',
        'api/public/orders/metrics/tabularview',
        'api/public/bookings/audit/assignee-performance/tabularview',
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.queryParameters, {
          'shopId': 5,
          'startDate': '2026-10-10',
          'endDate': '2026-10-10',
        });
        expect(request.extra[AuthInterceptor.safeRead], true);
      }
    },
  );

  test('rows-only envelope and bare arrays work; malformed envelopes never succeed empty', () {
    expect(DashboardDto.rows([backendBookingRow]), hasLength(1));
    expect(
      DashboardDto.rows({
        'rows': [backendBookingRow],
      }),
      hasLength(1),
    );
    expect(DashboardDto.rows(backendReport([])), isEmpty);
    for (final body in [
      null,
      {},
      {'rows': null},
      {'rows': 'bad'},
      {
        'rows': [null],
      },
      {'rows': [], 'summaryMetrics': {}},
      {
        'rows': [],
        'columns': [false],
      },
    ]) {
      expect(() => DashboardDto.rows(body), throwsA(isA<ContractFailure>()));
    }
  });

  test('BigDecimal numbers/strings work but null, invalid or negative core money fails', () {
    expect(DashboardDto.amount('125.25'), 125.25);
    expect(DashboardDto.amount('1.25E2'), 125);
    expect(DashboardDto.amount(125.25), 125.25);
    for (final value in [null, '', 'invalid', 'NaN', 'Infinity', -1, true]) {
      expect(() => DashboardDto.amount(value), throwsA(isA<ContractFailure>()));
    }
    for (final key in [
      'finalAmount',
      'remainingAmountPaid',
      'walletCreditUsed',
      'bookingId',
      'bookingDate',
    ]) {
      expect(
        () => DashboardDto.booking({...backendBookingRow, key: null}),
        throwsA(isA<ContractFailure>()),
      );
    }
    expect(
      () => DashboardDto.booking({...backendBookingRow, 'bookingId': '41'}),
      throwsA(isA<ContractFailure>()),
    );
    expect(
      () =>
          DashboardDto.assignee({...backendAssigneeRow, 'servicePrice': null}),
      throwsA(isA<ContractFailure>()),
    );
  });

  test('lower reports use current DTOs and preserve unknown status rather than guessing', () async {
    final payloads = <String, Object?>{
      'api/public/bookings/audit/booking-status-rows/tabularview':
          backendReport([
            {'bookingId': 41, 'bookingDate': '2026-10-10', 'status': null},
          ]),
      'api/products/inventory-alerts/tabularview': backendReport([
        {
          'productId': 2,
          'productName': 'Synthetic Product',
          'currentStock': 2,
          'lowStockThreshold': 2,
          'stockColor': 'warning',
        },
      ]),
      'api/wallet-purchases/metrics/tabularview': backendReport([
        {
          'purchaseId': 3,
          'purchaseDate': '2026-10-10',
          'walletType': 'CREDIT',
          'walletPlanName': null,
          'amount': '100.50',
        },
      ]),
      'api/membership-enrollments/metrics/tabularview': backendReport([
        {
          'registrationId': 4,
          'enrollmentDate': '2026-10-10',
          'membershipName': null,
          'amount': 200.25,
        },
      ]),
    };
    final adapter = StubAdapter((r) => (status: 200, body: payloads[r.path]));
    final client = stubClient(adapter);
    addTearDown(client.close);
    final repository = DashboardRepositoryImpl(client);
    expect(
      DashboardAnalytics.appointmentCounts(
        (await repository.statuses(5, window)).rows,
      ).values,
      {'Unknown status': 1},
    );
    expect((await repository.inventory(5)).rows.single.lowStock, true);
    expect(
      (await repository.walletPurchases(5, window)).rows.single.amount,
      100.50,
    );
    expect(
      (await repository.membershipSales(5, window)).rows.single.amount,
      200.25,
    );
    expect(adapter.requests[1].queryParameters, {'shopId': 5});
    expect(
      () => DashboardDto.inventory({'id': 2, 'name': 'Not the reporting DTO'}),
      throwsA(isA<ContractFailure>()),
    );
  });

  test(
    'HTTP and malformed successful responses remain typed failures',
    () async {
      for (final response in [
        (status: 200, body: <String, Object?>{'rows': null}),
        (status: 500, body: backendReport([])),
        (status: 403, body: backendReport([])),
      ]) {
        final client = stubClient(StubAdapter((_) => response));
        addTearDown(client.close);
        final failure = response.status == 500
            ? isA<ServerFailure>()
            : response.status == 403
            ? isA<ForbiddenFailure>()
            : isA<ContractFailure>();
        await expectLater(
          DashboardRepositoryImpl(client).bookings(5, window),
          throwsA(failure),
        );
      }
    },
  );
}
