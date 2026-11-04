import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import 'cognito_identity_decoder.dart';

/// Strict contract mapping shared by sign-in, refresh and secure restoration.
class SignInResponseDto {
  const SignInResponseDto._(this.json);
  final Map<String, Object?> json;
  static SignInResponseDto parse(Object? value) {
    if (value is! Map<String, Object?>) throw const ContractFailure();
    return SignInResponseDto._(value);
  }

  SignInOutcome toOutcome(DateTime receivedAt, {String? oldRefresh}) {
    final change = json['requiresPasswordChange'];
    final challenge = json['challengeName'];
    if ((change != null && change is! bool) ||
        (challenge != null && challenge is! String)) {
      throw const ContractFailure();
    }
    if (change == true ||
        (challenge is String && challenge.trim().isNotEmpty)) {
      return const ActionRequired();
    }
    final access = _text('accessToken');
    final id = _text('idToken');
    final refresh = json.containsKey('refreshToken')
        ? _text('refreshToken')
        : oldRefresh;
    if (refresh == null ||
        refresh.trim().isEmpty ||
        _text('tokenType') != 'Bearer') {
      throw const ContractFailure();
    }
    final seconds = json['expiresIn'];
    if (seconds is! int || seconds <= 0 || seconds > 31536000) {
      throw const ContractFailure();
    }
    final idClaims = CognitoIdentityDecoder.payload(id);
    final accessExpiry = CognitoIdentityDecoder.expiry(
      CognitoIdentityDecoder.payload(access),
    );
    final bound = receivedAt.add(Duration(seconds: seconds));
    return Authenticated(
      AuthSession(
        CognitoIdentityDecoder.identity(idClaims, _userId(), _text('email')),
        SessionTokens(
          accessToken: access,
          idToken: id,
          refreshToken: refresh,
          receivedAt: receivedAt,
          expiresAt: accessExpiry.isBefore(bound) ? accessExpiry : bound,
          idExpiresAt: CognitoIdentityDecoder.expiry(idClaims),
          expiresIn: seconds,
        ),
      ),
    );
  }

  String _userId() {
    final value = json['userId'];
    if (value is int) return value.toString();
    // Secure bundles and existing internal identities store IDs as strings.
    return _text('userId');
  }

  String _text(String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) throw const ContractFailure();
    return value;
  }
}
