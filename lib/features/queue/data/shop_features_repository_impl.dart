import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../domain/shop_features_repository.dart';

class ShopFeaturesRepositoryImpl implements ShopFeaturesRepository {
  const ShopFeaturesRepositoryImpl(this.client);

  final Dio client;

  @override
  Future<Set<String>> loadEnabledFeatures(int shopId) async {
    try {
      final response = await client.get<Object?>(
        'api/shop-features/me',
        queryParameters: {'shopId': shopId},
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      return parse(response.data);
    } on DioException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }

  static Set<String> parse(Object? value) {
    if (value is! List) throw const ContractFailure();
    return {
      for (final key in value)
        if (key is String && key.trim().isNotEmpty) key.trim(),
    };
  }
}
