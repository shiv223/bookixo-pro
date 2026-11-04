import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/time/session_clock.dart';
import '../data/auth_repository_impl.dart';
import '../data/mock_auth_repository.dart';
import '../data/refresh_transport.dart';
import '../data/secure_session_store.dart';
import '../domain/auth_repository.dart';

final configProvider = Provider<AppConfig>((ref) => AppConfig.environment());
final clockProvider = Provider<SessionClock>(
  (ref) => const SystemSessionClock(),
);
final renewalLeadProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
);
final secureStoreProvider = Provider<SecureSessionStore>(
  (ref) =>
      SecureSessionStore(const PlatformSecureBackend(FlutterSecureStorage())),
);
final authClientProvider = Provider((ref) {
  final client = createDio(ref.watch(configProvider));
  ref.onDispose(() => client.close(force: true));
  return client;
});
final refreshTransportProvider = Provider<RefreshTransport>(
  (ref) => DioRefreshTransport(
    ref.watch(authClientProvider),
    ref.watch(clockProvider),
  ),
);
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final clock = ref.watch(clockProvider);
  if (ref.watch(configProvider).demo) return MockAuthRepository(clock);
  return AuthRepositoryImpl(
    ref.watch(authClientProvider),
    ref.watch(secureStoreProvider),
    ref.watch(refreshTransportProvider),
    clock,
  );
});
