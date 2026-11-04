import 'dashboard_models.dart';

abstract interface class DashboardRepository {
  Future<DashboardRows<BookingReportRow>> bookings(
    int shopId,
    DateWindow window,
  );
  Future<DashboardRows<ProductOrderRow>> orders(int shopId, DateWindow window);
  Future<DashboardRows<AssigneeServiceRow>> staffServices(
    int shopId,
    DateWindow window,
  );
  Future<DashboardRows<BookingStatusRow>> statuses(
    int shopId,
    DateWindow window,
  );
  Future<DashboardRows<InventoryProduct>> inventory(int shopId);
  Future<DashboardRows<WalletPurchaseRow>> walletPurchases(
    int shopId,
    DateWindow window,
  );
  Future<DashboardRows<MembershipSaleRow>> membershipSales(
    int shopId,
    DateWindow window,
  );
}
