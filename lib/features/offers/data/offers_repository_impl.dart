import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../menu/domain/menu_snapshot.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';
import 'offers_dto.dart';

/// All resources use validated shopId and the protected ACCESS-token client.
class OffersRepositoryImpl implements OffersRepository {
  const OffersRepositoryImpl(this.client);
  final Dio client;
  Future<ResourcePage<T>> _get<T>(
    MenuScope scope,
    int page,
    String path,
    T Function(Object?) parse,
  ) async {
    if (scope.userId.trim().isEmpty ||
        scope.shopId <= 0 ||
        page < 0 ||
        page > 9) {
      throw const ContractFailure();
    }
    try {
      final response = await client.get<Object?>(
        path,
        queryParameters: {'shopId': scope.shopId, 'page': page, 'size': 100},
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return OffersDto.page(response.data, page, parse);
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }

  @override
  Future<ResourcePage<Offer>> offers(MenuScope scope, int page) =>
      _get(scope, page, 'api/shop-offers', OffersDto.offer);
  @override
  Future<ResourcePage<OfferTarget>> targets(MenuScope scope, int page) =>
      _get(scope, page, 'api/offer-targets', OffersDto.target);
  @override
  Future<ResourcePage<ScheduleRule>> rules(MenuScope scope, int page) =>
      _get(scope, page, 'api/offer-schedule-rules', OffersDto.rule);
}
