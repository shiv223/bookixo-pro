import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_repository.dart';
import 'dashboard_dto.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this.client);
  final Dio client;

  Future<DashboardRows<T>> _report<T>(
    String path,
    int shopId,
    DateWindow window,
    T Function(Object?) parse,
  ) => _get(path, {
    'shopId': shopId,
    'startDate': window.startDate,
    'endDate': window.endDate,
  }, parse);

  Future<DashboardRows<T>> _get<T>(
    String path,
    Map<String, Object> query,
    T Function(Object?) parse,
  ) async {
    if ((query['shopId'] as int) <= 0) throw const ContractFailure();
    try {
      final response = await client.get<Object?>(
        path,
        queryParameters: query,
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return DashboardRows(DashboardDto.rows(response.data).map(parse));
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on TypeError catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }

  @override
  Future<DashboardRows<BookingReportRow>> bookings(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/public/bookings/audit/booking-metrics/tabularview',
    shopId,
    window,
    DashboardDto.booking,
  );

  @override
  Future<DashboardRows<ProductOrderRow>> orders(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/public/orders/metrics/tabularview',
    shopId,
    window,
    DashboardDto.order,
  );

  @override
  Future<DashboardRows<AssigneeServiceRow>> staffServices(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/public/bookings/audit/assignee-performance/tabularview',
    shopId,
    window,
    DashboardDto.assignee,
  );

  @override
  Future<DashboardRows<BookingStatusRow>> statuses(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/public/bookings/audit/booking-status-rows/tabularview',
    shopId,
    window,
    DashboardDto.status,
  );

  @override
  Future<DashboardRows<InventoryProduct>> inventory(int shopId) => _get(
    'api/products/inventory-alerts/tabularview',
    {'shopId': shopId},
    DashboardDto.inventory,
  );

  @override
  Future<DashboardRows<WalletPurchaseRow>> walletPurchases(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/wallet-purchases/metrics/tabularview',
    shopId,
    window,
    DashboardDto.walletPurchase,
  );

  @override
  Future<DashboardRows<MembershipSaleRow>> membershipSales(
    int shopId,
    DateWindow window,
  ) => _report(
    'api/membership-enrollments/metrics/tabularview',
    shopId,
    window,
    DashboardDto.membershipSale,
  );
}
