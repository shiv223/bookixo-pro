import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/time/session_clock.dart';
import '../domain/menu_repository.dart';
import '../domain/menu_snapshot.dart';
import 'menu_cache_store.dart';
import 'menu_response_dto.dart';

/// Reuses bounded protected-GET authentication recovery.
class MenuRepositoryImpl implements MenuRepository {
  MenuRepositoryImpl(this.client, this.cache, this.clock);
  final Dio client;
  final MenuCacheStore cache;
  final SessionClock clock;
  @override
  Future<MenuSnapshot> fetch(MenuScope scope) async {
    if (scope.shopId <= 0 || scope.userId.isEmpty) {
      throw const ContractFailure();
    }
    try {
      final response = await client.get<Object?>(
        'api/navigation/me',
        queryParameters: {'shopId': scope.shopId},
        options: Options(extra: {AuthInterceptor.safeRead: true}),
      );
      final dto = MenuResponseDto.parse(response.data);
      return MenuSnapshot(
        scope,
        dto.keys,
        clock.now(),
        shopSetupChildren: dto.shopSetupChildren,
      );
    } on DioException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s), s);
    }
  }

  @override
  Future<MenuSnapshot?> read(MenuScope scope) => cache.read(scope);
  @override
  Future<void> write(MenuSnapshot snapshot, bool Function() current) =>
      cache.write(snapshot, current);
  @override
  Future<void> clear() => cache.clear();
}
