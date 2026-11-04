import 'package:flutter_test/flutter_test.dart';
import 'package:bookixo_pro/features/dashboard/data/dashboard_dto.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_analytics.dart';
import 'package:bookixo_pro/features/dashboard/domain/dashboard_models.dart';
import 'package:bookixo_pro/features/dashboard/presentation/dashboard_format.dart';

void main() {
  group('Dashboard date windows', () {
    test(
      'uses Asia/Kolkata calendar date rather than device calendar date',
      () {
        final utc = DateTime.utc(2026, 10, 9, 20);
        final window = DashboardAnalytics.currentWindow(
          DashboardRange.today,
          utc,
        );

        expect(window.startDate, '2026-10-10');
        expect(window.endDate, '2026-10-10');
      },
    );

    test(
      'uses inclusive rolling periods and preceding equal-length period',
      () {
        final now = DateTime.utc(2026, 6, 20, 10);
        final seven = DashboardAnalytics.currentWindow(
          DashboardRange.sevenDays,
          now,
        );
        final sevenPrevious = DashboardAnalytics.previousWindow(seven);
        final thirty = DashboardAnalytics.currentWindow(
          DashboardRange.thirtyDays,
          now,
        );

        expect(seven.startDate, '2026-06-14');
        expect(seven.endDate, '2026-06-20');
        expect(sevenPrevious.startDate, '2026-06-07');
        expect(sevenPrevious.endDate, '2026-06-13');
        expect(thirty.startDate, '2026-05-22');
        expect(thirty.endDate, '2026-06-20');
      },
    );
  });

  test('suppresses comparison when previous total is zero', () {
    expect(DashboardAnalytics.percentChange(100, 0), isNull);
    expect(DashboardAnalytics.percentChange(150, 100), 50);
    expect(DashboardAnalytics.percentChange(49, 100), -51);
  });

  test('formats rupees using Indian grouping and compact large values', () {
    expect(formatInr(12345678.8), '₹1,23,45,679');
    expect(formatInr(100000, compact: true), '₹1L');
    expect(formatInr(10500000, compact: true), '₹1.1Cr');
  });

  test(
    'deduplicates booking billing counts and sums only net collected value',
    () {
      final rows = [
        _booking(1, remaining: 650, finalAmount: 1000),
        _booking(1, remaining: 650, finalAmount: 1000),
        _booking(2, remaining: 700, finalAmount: 700),
      ];

      expect(DashboardAnalytics.completedBills(rows), 2);
      expect(
        DashboardAnalytics.sumBookings(rows, (row) => row.remainingAmountPaid),
        1350,
      );
    },
  );

  test(
    'Today is one gross total; weekly and monthly trend are deterministic',
    () {
      final window = DateWindow(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 3, 7),
      );
      final bookings = [
        _booking(
          1,
          remaining: 700,
          finalAmount: 800,
          date: DateTime.utc(2026, 3, 2),
        ),
        _booking(
          2,
          remaining: 200,
          finalAmount: 300,
          date: DateTime.utc(2026, 3, 4),
        ),
      ];
      final orders = [_order(4, 100, DateTime.utc(2026, 3, 4))];

      final today = DashboardAnalytics.trend(
        range: DashboardRange.today,
        window: window,
        bookings: bookings,
        orders: orders,
      );
      expect(today.map((bucket) => bucket.label), ['Today']);
      expect(today.map((bucket) => bucket.amount), [1200]);
      final daily = DashboardAnalytics.trend(
        range: DashboardRange.sevenDays,
        window: window,
        bookings: bookings,
        orders: orders,
      );
      expect(daily.map((bucket) => bucket.amount), [800, 400]);
      final monthly = DashboardAnalytics.trend(
        range: DashboardRange.thirtyDays,
        window: DateWindow(DateTime.utc(2026, 3, 1), DateTime.utc(2026, 3, 30)),
        bookings: bookings,
        orders: orders,
      );
      expect(monthly.map((bucket) => bucket.amount), [1200]);
      expect(
        DashboardAnalytics.trend(
          range: DashboardRange.today,
          window: window,
          bookings: const [],
          orders: const [],
        ),
        isEmpty,
      );
    },
  );

  test('appointments preserve in-progress and unknown statuses explicitly', () {
    final counts = DashboardAnalytics.appointmentCounts([
      _status(1, 'COMPLETED'),
      _status(2, 'PENDING'),
      _status(3, 'IN_PROGRESS'),
      _status(4, 'CONFIRMED'),
      _status(5, 'REJECTED'),
      _status(6, 'UNRECOGNIZED'),
      _status(6, 'CANCELLED'),
    ]).values;

    expect(counts, {
      'Completed': 1,
      'Pending': 1,
      'In progress': 1,
      'Confirmed': 1,
      'No Show': 1,
      'Cancelled': 1,
    });
  });

  test('top services use catalogServices and top staff use unique clients', () {
    final staffRows = [
      _assignee(1, 'a@shop.test', 'Asha', 'Hair cut', 400, 'client-a'),
      _assignee(2, 'a@shop.test', 'Asha', 'Hair cut', 300, 'client-a'),
      _assignee(3, 'b@shop.test', 'Bea', 'Hair spa', 500, 'client-b'),
    ];

    expect(DashboardAnalytics.topServices(staffRows).first.label, 'Hair cut');
    final staff = DashboardAnalytics.topStaff(staffRows);
    expect(staff.first.name, 'Asha');
    expect(staff.first.clients, 1);
    expect(staff.first.revenue, 700);
  });

  test('current-stock filtering uses danger/warning and the threshold', () {
    const rows = [
      InventoryProduct(
        productId: 1,
        name: 'Below',
        currentStock: 1,
        lowStockThreshold: 3,
        stockColor: 'danger',
      ),
      InventoryProduct(
        productId: 2,
        name: 'At threshold',
        currentStock: 3,
        lowStockThreshold: 3,
        stockColor: 'warning',
      ),
      InventoryProduct(
        productId: 3,
        name: 'Healthy',
        currentStock: 9,
        lowStockThreshold: 3,
        stockColor: 'success',
      ),
    ];

    expect(rows.where((item) => item.lowStock).map((item) => item.name), [
      'Below',
      'At threshold',
    ]);
  });

  test(
    'report DTO rejects malformed envelopes and missing required values',
    () {
      expect(
        () => DashboardDto.rows({
          'columns': [],
          'rows': null,
          'summaryMetrics': [],
        }),
        throwsA(isA<Exception>()),
      );
      expect(
        () => DashboardDto.booking({
          'bookingId': 1,
          'bookingDate': '2026-02-30',
          'finalAmount': 100,
          'remainingAmountPaid': 90,
          'walletCreditUsed': 10,
          'paymentMode': 'UPI',
        }),
        throwsA(isA<Exception>()),
      );
      expect(
        () => DashboardDto.order({
          'orderId': 4,
          'orderDate': '2026-03-01',
          'grandTotal': 'not-a-number',
        }),
        throwsA(isA<Exception>()),
      );
      expect(
        DashboardDto.rows({
          'columns': [],
          'rows': [
            {
              'bookingId': 1,
              'bookingDate': '2026-03-01',
              'finalAmount': 100,
              'remainingAmountPaid': 90,
              'walletCreditUsed': 10,
              'paymentMode': 'UPI',
            },
          ],
          'summaryMetrics': [],
        }).single['bookingId'],
        1,
      );
    },
  );
}

BookingReportRow _booking(
  int id, {
  required double remaining,
  required double finalAmount,
  DateTime? date,
}) => BookingReportRow(
  bookingId: id,
  bookingDate: date ?? DateTime.utc(2026, 3, 1),
  finalAmount: finalAmount,
  remainingAmountPaid: remaining,
  walletCreditUsed: 0,
  paymentMode: 'UPI',
);

ProductOrderRow _order(int id, double amount, DateTime date) => ProductOrderRow(
  orderId: id,
  orderDate: date,
  grandTotal: amount,
  paymentMode: 'Card',
);

BookingStatusRow _status(int id, String status) => BookingStatusRow(
  bookingId: id,
  status: status,
  bookingDate: DateTime.utc(2026, 3, 1),
);

AssigneeServiceRow _assignee(
  int bookingId,
  String identity,
  String name,
  String service,
  double amount,
  String client,
) => AssigneeServiceRow(
  bookingId: bookingId,
  identity: identity,
  displayName: name,
  catalogServices: service,
  servicePrice: amount,
  customerIdentity: client,
);
