import 'dashboard_models.dart';

class DashboardAnalytics {
  const DashboardAnalytics._();

  static DateTime shopDate(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 5, minutes: 30));

  static DateWindow currentWindow(DashboardRange range, DateTime now) {
    final today = shopDate(now);
    final days = switch (range) {
      DashboardRange.today => 1,
      DashboardRange.sevenDays => 7,
      DashboardRange.thirtyDays => 30,
    };
    final end = DateTime.utc(today.year, today.month, today.day);
    return DateWindow(end.subtract(Duration(days: days - 1)), end);
  }

  static DateWindow previousWindow(DateWindow current) {
    final days = current.end.difference(current.start).inDays + 1;
    final end = current.start.subtract(const Duration(days: 1));
    return DateWindow(end.subtract(Duration(days: days - 1)), end);
  }

  static double sumBookings(
    List<BookingReportRow> rows,
    double Function(BookingReportRow) select,
  ) {
    final seen = <int>{};
    return rows.fold(
      0,
      (sum, row) => seen.add(row.bookingId) ? sum + select(row) : sum,
    );
  }

  static double sumOrders(List<ProductOrderRow> rows) {
    final seen = <int>{};
    return rows.fold(
      0,
      (sum, row) => seen.add(row.orderId) ? sum + row.grandTotal : sum,
    );
  }

  static int completedBills(List<BookingReportRow> rows) =>
      rows.map((row) => row.bookingId).toSet().length;

  static int uniqueCount(Iterable<String> values) =>
      values.where((value) => value.isNotEmpty).toSet().length;

  static int? percentChange(double current, double previous) {
    if (previous <= 0) return null;
    return ((current - previous) / previous * 100).round();
  }

  static List<TrendBucket> trend({
    required DashboardRange range,
    required DateWindow window,
    required List<BookingReportRow> bookings,
    required List<ProductOrderRow> orders,
  }) {
    if (range == DashboardRange.today) {
      final total =
          sumBookings(bookings, (row) => row.finalAmount) + sumOrders(orders);
      return total > 0 ? [TrendBucket('Today', total)] : const [];
    }
    final grouped = <DateTime, double>{};
    void add(DateTime date, double amount) {
      final bucket = range == DashboardRange.sevenDays
          ? DateTime.utc(date.year, date.month, date.day)
          : DateTime.utc(
              date.year,
              date.month,
              date.day,
            ).subtract(Duration(days: (date.weekday + 6) % 7));
      grouped.update(bucket, (value) => value + amount, ifAbsent: () => amount);
    }

    for (final row in bookings) {
      add(row.bookingDate, row.finalAmount);
    }
    for (final row in orders) {
      add(row.orderDate, row.grandTotal);
    }
    final result = <TrendBucket>[];
    final span = range == DashboardRange.sevenDays ? 1 : 7;
    for (
      var date = window.start;
      !date.isAfter(window.end);
      date = date.add(Duration(days: span))
    ) {
      final key = range == DashboardRange.sevenDays
          ? date
          : date.subtract(Duration(days: (date.weekday + 6) % 7));
      final amount = grouped[key] ?? 0;
      if (amount > 0) {
        result.add(TrendBucket('${date.day}/${date.month}', amount));
      }
    }
    return result;
  }

  static List<RankedValue> topServices(
    List<AssigneeServiceRow> rows, {
    int limit = 5,
  }) {
    final values = <String, double>{};
    for (final row in rows) {
      // Each backend row is a service snapshot, not a booking aggregate.
      // Identical-looking lines can be distinct snapshots and must all count.
      final service = row.catalogServices.trim();
      if (service.isNotEmpty) {
        values.update(
          service,
          (value) => value + row.servicePrice,
          ifAbsent: () => row.servicePrice,
        );
      }
    }
    return _rank(values, limit);
  }

  static List<StaffSummary> topStaff(
    List<AssigneeServiceRow> rows, {
    int limit = 4,
  }) {
    final values = <String, double>{};
    final names = <String, String>{};
    final clients = <String, Set<String>>{};
    for (final row in rows) {
      values.update(
        row.identity,
        (value) => value + row.servicePrice,
        ifAbsent: () => row.servicePrice,
      );
      names[row.identity] = row.displayName;
      clients
          .putIfAbsent(row.identity, () => <String>{})
          .add(row.customerIdentity);
    }
    final staff =
        values.entries
            .map(
              (entry) => StaffSummary(
                identity: entry.key,
                name: names[entry.key] ?? 'Staff',
                revenue: entry.value,
                clients: clients[entry.key]?.length ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return staff.take(limit).toList();
  }

  static List<RankedValue> _rank(Map<String, double> values, int limit) {
    final items =
        values.entries
            .map((entry) => RankedValue(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return items.take(limit).toList();
  }

  static AppointmentCounts appointmentCounts(List<BookingStatusRow> rows) {
    final byId = <int, String>{};
    for (final row in rows) {
      byId[row.bookingId] = row.status.trim().toUpperCase();
    }
    final counts = <String, int>{};
    for (final status in byId.values) {
      final label = switch (status) {
        'COMPLETED' => 'Completed',
        'PENDING' => 'Pending',
        'CANCELLED' => 'Cancelled',
        'IN_PROGRESS' => 'In progress',
        'CONFIRMED' => 'Confirmed',
        'REJECTED' => 'No Show',
        _ => status.isEmpty ? 'Unknown status' : status,
      };
      counts.update(label, (count) => count + 1, ifAbsent: () => 1);
    }
    return AppointmentCounts(counts);
  }
}

class TrendBucket {
  const TrendBucket(this.label, this.amount);
  final String label;
  final double amount;
}

class RankedValue {
  const RankedValue(this.label, this.amount);
  final String label;
  final double amount;
}

class StaffSummary {
  const StaffSummary({
    required this.identity,
    required this.name,
    required this.revenue,
    required this.clients,
  });
  final String identity;
  final String name;
  final double revenue;
  final int clients;
}

class AppointmentCounts {
  const AppointmentCounts(this.values);
  final Map<String, int> values;
}
