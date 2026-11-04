import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';

class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository();
  static DateTime _date(DateWindow window, int offset) =>
      window.start.add(Duration(days: offset));

  @override
  Future<DashboardRows<BookingReportRow>> bookings(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([
    BookingReportRow(
      bookingId: 1,
      bookingDate: _date(window, 0),
      finalAmount: 1450,
      remainingAmountPaid: 1250,
      walletCreditUsed: 200,
      paymentMode: 'UPI',
    ),
    BookingReportRow(
      bookingId: 2,
      bookingDate: _date(window, 0),
      finalAmount: 900,
      remainingAmountPaid: 900,
      walletCreditUsed: 0,
      paymentMode: 'Cash',
    ),
  ]);

  @override
  Future<DashboardRows<ProductOrderRow>> orders(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([
    ProductOrderRow(
      orderId: 31,
      orderDate: _date(window, 0),
      grandTotal: 625,
      paymentMode: 'Card',
    ),
  ]);

  @override
  Future<DashboardRows<AssigneeServiceRow>> staffServices(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([
    AssigneeServiceRow(
      bookingId: 1,
      identity: 'staff-1',
      displayName: 'Aarav',
      catalogServices: 'Hair spa',
      servicePrice: 1450,
      customerIdentity: 'client-1',
    ),
    AssigneeServiceRow(
      bookingId: 2,
      identity: 'staff-2',
      displayName: 'Maya',
      catalogServices: 'Hair cut',
      servicePrice: 900,
      customerIdentity: 'client-2',
    ),
  ]);

  @override
  Future<DashboardRows<BookingStatusRow>> statuses(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([
    BookingStatusRow(
      bookingId: 1,
      status: 'COMPLETED',
      bookingDate: _date(window, 0),
    ),
    BookingStatusRow(
      bookingId: 2,
      status: 'IN_PROGRESS',
      bookingDate: _date(window, 0),
    ),
    BookingStatusRow(
      bookingId: 3,
      status: 'PENDING',
      bookingDate: _date(window, 0),
    ),
  ]);

  @override
  Future<DashboardRows<InventoryProduct>> inventory(int shopId) async =>
      DashboardRows([
        const InventoryProduct(
          productId: 4,
          name: 'Coconut serum',
          currentStock: 2,
          lowStockThreshold: 5,
          stockColor: 'warning',
        ),
        const InventoryProduct(
          productId: 5,
          name: 'Shampoo',
          currentStock: 14,
          lowStockThreshold: 5,
          stockColor: 'success',
        ),
      ]);

  @override
  Future<DashboardRows<WalletPurchaseRow>> walletPurchases(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([
    WalletPurchaseRow(walletType: 'PACKAGE', amount: 1200),
    WalletPurchaseRow(walletType: 'CREDIT', amount: 500),
  ]);

  @override
  Future<DashboardRows<MembershipSaleRow>> membershipSales(
    int shopId,
    DateWindow window,
  ) async => DashboardRows([MembershipSaleRow(amount: 2000)]);
}
