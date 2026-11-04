import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/dashboard_models.dart';

/// Validates the two response envelopes used by the report APIs.
abstract final class DashboardDto {
  static List<Map<String, Object?>> rows(Object? body) {
    Object? value = body;
    if (value is Map<String, Object?>) {
      // Dashboard consumes rows only. Metadata is optional, but when present
      // follows AssigneeTabularViewResponseDto's list-valued contract.
      for (final key in ['columns', 'summaryMetrics']) {
        final metadata = value[key];
        if (metadata != null) {
          if (metadata is! List) throw const ContractFailure();
          metadata.forEach(object);
        }
      }
      value = value['rows'];
    }
    if (value is! List) throw const ContractFailure();
    return value.map(object).toList(growable: false);
  }

  static Map<String, Object?> object(Object? value) {
    if (value is! Map<String, Object?>) throw const ContractFailure();
    return value;
  }

  static int integer(Object? value, {int minimum = 0}) {
    if (value is! int || value < minimum) throw const ContractFailure();
    return value;
  }

  static double amount(Object? value) {
    // Jackson BigDecimal normally encodes as a number; decimal strings are
    // also accepted without treating null or malformed money as zero.
    final parsed = value is num
        ? value.toDouble()
        : value is String && value.trim().isNotEmpty
        ? double.tryParse(value.trim())
        : null;
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      throw const ContractFailure();
    }
    return parsed;
  }

  static String optionalText(Object? value) =>
      value == null ? '' : text(value, allowEmpty: true);

  static String text(Object? value, {bool allowEmpty = false}) {
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw const ContractFailure();
    }
    return value.trim();
  }

  static DateTime date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const ContractFailure();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw const ContractFailure();
    }
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static BookingReportRow booking(Object? value) {
    final row = object(value);
    return BookingReportRow(
      bookingId: integer(row['bookingId'], minimum: 1),
      bookingDate: date(row['bookingDate']),
      finalAmount: amount(row['finalAmount']),
      remainingAmountPaid: amount(row['remainingAmountPaid']),
      walletCreditUsed: amount(row['walletCreditUsed']),
      paymentMode: optionalText(row['paymentMode']),
    );
  }

  static ProductOrderRow order(Object? value) {
    final row = object(value);
    return ProductOrderRow(
      orderId: integer(row['orderId'], minimum: 1),
      orderDate: date(row['orderDate']),
      grandTotal: amount(row['grandTotal']),
      paymentMode: optionalText(row['paymentMode']),
    );
  }

  static AssigneeServiceRow assignee(Object? value) {
    final row = object(value);
    final bookingId = integer(row['bookingId'], minimum: 1);
    // The current reporting delegate puts assignedNameSnapshot in
    // assigneeEmail and does not populate assigneeName/contactNumber.
    final email = optionalText(row['assigneeEmail']);
    final name = optionalText(row['assigneeName']);
    final customer = optionalText(row['contactNumber']);
    return AssigneeServiceRow(
      bookingId: bookingId,
      identity: email.isNotEmpty
          ? email.toLowerCase()
          : name.isNotEmpty
          ? name.toLowerCase()
          : 'staff-unavailable',
      displayName: name.isNotEmpty
          ? name
          : email.isNotEmpty
          ? email
          : AppStrings.dashboardStaffUnavailable,
      catalogServices: optionalText(row['catalogServices']),
      servicePrice: amount(row['servicePrice']),
      customerIdentity: customer.isNotEmpty ? customer : 'booking-$bookingId',
    );
  }

  static BookingStatusRow status(Object? value) {
    final row = object(value);
    return BookingStatusRow(
      bookingId: integer(row['bookingId'], minimum: 1),
      status: optionalText(row['status']),
      bookingDate: date(row['bookingDate']),
    );
  }

  static InventoryProduct inventory(Object? value) {
    final row = object(value);
    return InventoryProduct(
      productId: integer(row['productId'], minimum: 1),
      name: text(row['productName']),
      currentStock: integer(row['currentStock']),
      lowStockThreshold: integer(row['lowStockThreshold']),
      stockColor: text(row['stockColor']).toLowerCase(),
    );
  }

  static WalletPurchaseRow walletPurchase(Object? value) {
    final row = object(value);
    return WalletPurchaseRow(
      walletType: text(row['walletType']).toUpperCase(),
      amount: amount(row['amount']),
    );
  }

  static MembershipSaleRow membershipSale(Object? value) {
    final row = object(value);
    return MembershipSaleRow(amount: amount(row['amount']));
  }
}
