import 'auth_models.dart';

/// Narrow internal networking contract, not a widget credential provider.
abstract interface class SessionAccess {
  int get generation;
  AuthSession? get currentSession;
  Future<void> ensureFresh({bool force = false});
  Future<void> logout();
}
