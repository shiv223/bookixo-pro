import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../domain/auth_models.dart';

/// Structural decoding only: this does NOT verify signatures or authorize.
abstract final class CognitoIdentityDecoder {
  static Map<String, Object?> payload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
        throw const FormatException();
      }
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (json is! Map<String, Object?>) throw const FormatException();
      return json;
    } on FormatException catch (error, stack) {
      Error.throwWithStackTrace(DataFailureMapper.map(error, stack), stack);
    }
  }

  static DateTime expiry(Map<String, Object?> claims) {
    final exp = claims['exp'];
    if (exp is! int || exp <= 0 || exp > 8640000000000) {
      throw const ContractFailure();
    }
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  static AuthIdentity identity(
    Map<String, Object?> claims,
    String userId,
    String email,
  ) {
    final groups = claims['cognito:groups'];
    final subject = claims['sub'];
    if ((groups != null &&
            (groups is! List || groups.any((g) => g is! String))) ||
        (subject != null && subject is! String)) {
      throw const ContractFailure();
    }
    return AuthIdentity(
      userId: userId,
      email: email,
      subject: subject as String?,
      groups: groups == null ? [] : (groups as List).cast<String>(),
    );
  }
}
