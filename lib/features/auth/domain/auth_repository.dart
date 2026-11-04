import 'auth_models.dart';

/// Swappable authentication boundary; only secure data adapters persist tokens.
abstract interface class AuthRepository {
  Future<SignInOutcome> signIn(String identifier, String password);
  Future<AuthSession?> restore();
  Future<SignInOutcome> refresh(AuthSession session);
  Future<void> logout();
}
