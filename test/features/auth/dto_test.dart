import 'dart:convert';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/auth/data/sign_in_response_dto.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object?> claims) =>
    'e30.${base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '')}.signature';
final now = DateTime.utc(2026, 10, 6);
Map<String, Object?> response({List<String>? groups}) => {
  'accessToken': jwt({
    'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
  }),
  'idToken': jwt({
    'exp': now.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000,
    'cognito:groups': ?groups,
    'sub': 'fake-sub',
  }),
  'refreshToken': 'fake-refresh',
  'expiresIn': 3600,
  'tokenType': 'Bearer',
  'userId': 5,
  'email': 'person@example.test',
};

void main() {
  test('numeric API user ID is normalized to the internal string ID', () {
    final outcome = SignInResponseDto.parse(response()).toOutcome(now);
    expect((outcome as Authenticated).session.identity.userId, '5');
  });
  test('stored string user IDs remain readable', () {
    final outcome = SignInResponseDto.parse({...response(), 'userId': '5'})
        .toOutcome(now);
    expect((outcome as Authenticated).session.identity.userId, '5');
  });
  test('invalid user ID types never default or stringify', () {
    for (final value in [null, 5.5, true, <Object>[], <String, Object>{}]) {
      expect(
        () =>
            SignInResponseDto.parse({...response(), 'userId': value})
                .toOutcome(now),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
  test('missing groups safe; expiry bounded independently', () {
    final outcome = SignInResponseDto.parse(response()).toOutcome(now);
    expect(outcome, isA<Authenticated>());
    final session = (outcome as Authenticated).session;
    expect(session.identity.role, AppRole.unknown);
    expect(session.tokens.earliestExpiry, now.add(const Duration(minutes: 30)));
  });
  test('challenge needs no ordinary tokens and ignores message/session', () {
    expect(
      SignInResponseDto.parse({'requiresPasswordChange': true}).toOutcome(now),
      isA<ActionRequired>(),
    );
    expect(
      SignInResponseDto.parse({
        'challengeName': 'MFA',
        'session': 'do-not-store',
      }).toOutcome(now),
      isA<ActionRequired>(),
    );
  });
  test('refresh omission retains; present empty/null rejected', () {
    final omitted = response()..remove('refreshToken');
    expect(
      (SignInResponseDto.parse(omitted).toOutcome(
        now,
        oldRefresh: 'old',
      ) as Authenticated).session.tokens.refreshToken,
      'old',
    );
    for (final value in ['', null, 12]) {
      expect(
        () =>
            SignInResponseDto.parse({...response(), 'refreshToken': value})
                .toOutcome(now, oldRefresh: 'old'),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
  test('invalid success fields never default', () {
    for (final entry in {
      'accessToken': 'bad',
      'expiresIn': 0,
      'tokenType': 'Basic',
      'idToken': jwt({'exp': 'bad'}),
      'userId': '',
      'email': '',
    }.entries) {
      expect(
        () =>
            SignInResponseDto.parse({...response(), entry.key: entry.value})
                .toOutcome(now),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
  test('invalid group types and malformed payload rejected', () {
    for (final token in [
      'x.!.x',
      jwt({'exp': 2000000000, 'cognito:groups': 'OWNER'}),
      jwt({
        'exp': 2000000000,
        'cognito:groups': [1],
      }),
    ]) {
      expect(
        () =>
            SignInResponseDto.parse({...response(), 'idToken': token})
                .toOutcome(now),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
}
