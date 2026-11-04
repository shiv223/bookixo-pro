import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../menu/domain/menu_snapshot.dart';
import '../domain/shop_user.dart';
import '../domain/shop_users_repository.dart';
import 'shop_users_dto.dart';

/// Protected read-only directory. Contact data is neither cached nor logged.
class ShopUsersRepositoryImpl implements ShopUsersRepository {
  const ShopUsersRepositoryImpl(this.client);
  final Dio client;

  @override
  Future<ShopUsersPage> load(MenuScope scope, int page) async {
    if (scope.shopId <= 0 || scope.userId.trim().isEmpty || page < 0) {
      throw const ContractFailure();
    }
    try {
      final response = await client.get<Object?>(
        'api/users/shop-users',
        queryParameters: {
          'shopIds': scope.shopId,
          'page': page,
          'size': 20,
          'sort': 'id,desc',
        },
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return ShopUsersDto.page(response.data, page, scope.shopId);
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }
}
