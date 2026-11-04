import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/logging/app_logger.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../data/menu_cache_store.dart';
import '../data/menu_repository_impl.dart';
import '../data/mock_menu_repository.dart';
import '../domain/menu_repository.dart';

final menuCacheStoreProvider = Provider<MenuCacheStore>(
  (ref) => MenuCacheStore(const MenuSecureBackend(FlutterSecureStorage())),
);
final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  final clock = ref.watch(clockProvider);
  if (ref.watch(configProvider).demo) return MockMenuRepository(clock);
  return MenuRepositoryImpl(
    ref.watch(protectedClientProvider),
    ref.watch(menuCacheStoreProvider),
    clock,
  );
});
final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());
