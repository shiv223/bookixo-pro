import 'role_policy.dart';

/// Price-free identity derived afresh from server-issued display claims.
class AuthIdentity {
  AuthIdentity({
    required this.userId,
    required this.email,
    required List<String> groups,
    this.subject,
  }) : groups = List.unmodifiable(groups),
       role = RolePolicy.derive(groups);
  final String userId;
  final String email;
  final String? subject;
  final List<String> groups;
  final AppRole role;
}

/// Internal credentials. Deliberately no diagnostic string implementation.
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.receivedAt,
    required this.expiresAt,
    required this.idExpiresAt,
    required this.expiresIn,
  });
  final String accessToken;
  final String idToken;
  final String refreshToken;
  final DateTime receivedAt;
  final DateTime expiresAt;
  final DateTime idExpiresAt;
  final int expiresIn;
  DateTime get earliestExpiry =>
      expiresAt.isBefore(idExpiresAt) ? expiresAt : idExpiresAt;
  bool usable(DateTime now) => now.isBefore(earliestExpiry);
  DateTime renewAt(Duration lead) {
    final lifetime = earliestExpiry.difference(receivedAt);
    final bounded = Duration(milliseconds: lifetime.inMilliseconds ~/ 5);
    return earliestExpiry.subtract(bounded < lead ? bounded : lead);
  }
}

/// Session stays internal to lifecycle/network; screens receive identity only.
class AuthSession {
  const AuthSession(this.identity, this.tokens);
  final AuthIdentity identity;
  final SessionTokens tokens;
}

sealed class SignInOutcome {
  const SignInOutcome();
}

final class Authenticated extends SignInOutcome {
  const Authenticated(this.session);
  final AuthSession session;
}

final class ActionRequired extends SignInOutcome {
  const ActionRequired();
}

final class Superseded extends SignInOutcome {
  const Superseded();
}
