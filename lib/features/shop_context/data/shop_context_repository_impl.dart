import 'package:dio/dio.dart';

import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../domain/shop_context.dart';
import '../domain/shop_context_repository.dart';
import 'shop_context_dto.dart';

class ShopContextRepositoryImpl implements ShopContextRepository {
  const ShopContextRepositoryImpl(this.client);
  final Dio client;
  @override
  Future<ShopContext> load() async {
    try {
      final response = await client.get<Object?>(
        'api/users/my-shop-context',
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return ShopContextDto.parse(response.data).toDomain();
    } on DioException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s), s);
    }
  }
}

/// Explicit demo sample, never a production fallback after a failed request.
class MockShopContextRepository implements ShopContextRepository {
  const MockShopContextRepository();
  @override
  Future<ShopContext> load() async =>
      ShopContext(const [Shop(15, 'Demo salon'), Shop(16, 'Demo studio')], 15);
}
