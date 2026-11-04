import 'package:flutter/foundation.dart';

import '../../menu/domain/menu_snapshot.dart';

enum DashboardRange { today, sevenDays, thirtyDays }

enum DashboardResource {
  bookings,
  previousBookings,
  orders,
  previousOrders,
  staffServices,
  statuses,
  inventory,
  walletPurchases,
  membershipSales,
}

class DashboardScope {
  const DashboardScope({required this.menu, required this.ownership});

  final MenuScope menu;
  final int ownership;

  @override
  bool operator ==(Object other) =>
      other is DashboardScope &&
      other.menu == menu &&
      other.ownership == ownership;

  @override
  int get hashCode => Object.hash(menu, ownership);
}

@immutable
class DateWindow {
  const DateWindow(this.start, this.end);
  final DateTime start;
  final DateTime end;

  String get startDate => _dateText(start);
  String get endDate => _dateText(end);
}

String _dateText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

@immutable
class BookingReportRow {
  const BookingReportRow({
    required this.bookingId,
    required this.bookingDate,
    required this.finalAmount,
    required this.remainingAmountPaid,
    required this.walletCreditUsed,
    required this.paymentMode,
  });

  final int bookingId;
  final DateTime bookingDate;
  final double finalAmount;
  final double remainingAmountPaid;
  final double walletCreditUsed;
  final String paymentMode;
}

@immutable
class ProductOrderRow {
  const ProductOrderRow({
    required this.orderId,
    required this.orderDate,
    required this.grandTotal,
    required this.paymentMode,
  });

  final int orderId;
  final DateTime orderDate;
  final double grandTotal;
  final String paymentMode;
}

@immutable
class AssigneeServiceRow {
  const AssigneeServiceRow({
    required this.bookingId,
    required this.identity,
    required this.displayName,
    required this.catalogServices,
    required this.servicePrice,
    required this.customerIdentity,
  });

  final int bookingId;
  final String identity;
  final String displayName;
  final String catalogServices;
  final double servicePrice;
  final String customerIdentity;
}

@immutable
class BookingStatusRow {
  const BookingStatusRow({
    required this.bookingId,
    required this.status,
    required this.bookingDate,
  });

  final int bookingId;
  final String status;
  final DateTime bookingDate;
}

@immutable
class InventoryProduct {
  const InventoryProduct({
    required this.productId,
    required this.name,
    required this.currentStock,
    required this.lowStockThreshold,
    required this.stockColor,
  });

  final int productId;
  final String name;
  final int currentStock;
  final int lowStockThreshold;
  final String stockColor;

  bool get lowStock =>
      stockColor == 'danger' ||
      stockColor == 'warning' ||
      currentStock <= lowStockThreshold;
}

@immutable
class WalletPurchaseRow {
  const WalletPurchaseRow({required this.walletType, required this.amount});

  final String walletType;
  final double amount;
}

@immutable
class MembershipSaleRow {
  const MembershipSaleRow({required this.amount});

  final double amount;
}

class DashboardRows<T> {
  DashboardRows(Iterable<T> rows) : rows = List.unmodifiable(rows);
  final List<T> rows;
}

class DashboardResourceState<T> {
  const DashboardResourceState({
    this.value,
    this.loading = false,
    this.failure,
  });

  final T? value;
  final bool loading;
  final Object? failure;
}
