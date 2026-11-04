import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../menu/domain/menu_snapshot.dart';
import '../domain/shop_logo.dart';
import '../domain/shop_logo_repository.dart';
import 'shop_logo_dto.dart';

/// The protected client fetches JSON only, never the external artwork.
class ShopLogoRepositoryImpl implements ShopLogoRepository {
  const ShopLogoRepositoryImpl(this.client);
  final Dio client;
  @override
  Future<ShopLogo?> fetch(MenuScope scope) async {
    if (scope.userId.isEmpty || scope.shopId <= 0) {
      throw const ContractFailure();
    }
    try {
      final response = await client.get<Object?>(
        'api/shops/${scope.shopId}/logo',
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return ShopLogoDto.parse(response.statusCode, response.data).logo;
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }
}
