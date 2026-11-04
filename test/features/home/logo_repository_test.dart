import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/session_access.dart';
import 'package:bookixo_pro/features/home/data/shop_logo_dto.dart';
import 'package:bookixo_pro/features/home/data/shop_logo_repository_impl.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class LogoSession implements SessionAccess {
  AuthSession? session = sampleSession();
  int renewals = 0;
  int logouts = 0;
  @override
  int generation = 0;
  @override
  AuthSession? get currentSession => session;
  @override
  Future<void> ensureFresh({bool force = false}) async {
    if (force) {
      renewals++;
      session = sampleSession(salt: 'rotated');
    }
  }

  @override
  Future<void> logout() async {
    logouts++;
    generation++;
    session = null;
  }
}

void main() {
  const scope = MenuScope('5', null, 17);
  const url = 'https://images.example.test/logo?synthetic=fixture';
  test('200 parses HTTPS without an extension; 204 is absence', () {
    expect(ShopLogoDto.parse(200, {'logoUrl': url}).logo?.url, Uri.parse(url));
    expect(ShopLogoDto.parse(204, null).logo, isNull);
  });
  for (final body in [
    null,
    [],
    {},
    {'logoUrl': 42},
    {'logoUrl': ''},
    {'logoUrl': 'javascript:alert(1)'},
    {'logoUrl': 'http://example.test/a'},
    {'logoUrl': 'https://'},
    {'logoUrl': 'https://user:pass@example.test/a'},
    {'logoUrl': 'https://example.test/a b'},
    {'logoUrl': 'https://.'},
    {'logoUrl': 'https://example.test/a%zz'},
  ]) {
    test('malformed logo response is typed: $body', () {
      expect(
        () => ShopLogoDto.parse(200, body),
        throwsA(isA<ContractFailure>()),
      );
    });
  }
  test('presigned expiry is metadata, not a fixed 900-second contract', () {
    final logo = ShopLogoDto.parse(200, {
      'logoUrl': 'https://images.example.test/a?X-Amz-Date=20261006T000000Z&X-Amz-Expires=120',
    }).logo;
    expect(logo?.expiresAt, testNow.add(const Duration(seconds: 120)));
    expect(ShopLogoDto.parse(200, {'logoUrl': url}).logo?.expiresAt, isNull);
  });
  test(
    'validated shop path and ACCESS Bearer use existing safe GET recovery',
    () async {
      final session = LogoSession();
      final adapter = StubAdapter((_) => (status: 200, body: {'logoUrl': url}));
      final client = stubClient(adapter);
      client.interceptors.add(AuthInterceptor(client, session, FakeClock()));
      await ShopLogoRepositoryImpl(client).fetch(scope);
      final request = adapter.requests.single;
      expect(request.path, 'api/shops/17/logo');
      expect(
        request.headers['Authorization'],
        'Bearer ${session.session?.tokens.accessToken}',
      );
      expect(request.extra[AuthInterceptor.safeRead], true);
      expect(request.queryParameters, isEmpty);
    },
  );
  for (final status in [401, 403, 500]) {
    test('$status remains typed and 401 recovery is bounded', () async {
      final session = LogoSession();
      final adapter = StubAdapter((_) => (status: status, body: null));
      final client = stubClient(adapter);
      client.interceptors.add(AuthInterceptor(client, session, FakeClock()));
      await expectLater(
        ShopLogoRepositoryImpl(client).fetch(scope),
        throwsA(
          status == 401
              ? isA<UnauthorizedFailure>()
              : status == 403
              ? isA<ForbiddenFailure>()
              : isA<ServerFailure>(),
        ),
      );
      expect(adapter.requests.length, status == 401 ? 2 : 1);
      expect(session.renewals, status == 401 ? 1 : 0);
      expect(session.logouts, status == 401 ? 1 : 0);
    });
  }
  test('invalid scope never makes a request', () async {
    final adapter = StubAdapter((_) => (status: 204, body: null));
    await expectLater(
      ShopLogoRepositoryImpl(stubClient(adapter))
          .fetch(const MenuScope('5', null, 0)),
      throwsA(isA<ContractFailure>()),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    '200 malformed API body remains a contract error; 204 is not an error',
    () async {
      final malformed = StubAdapter((_) => (status: 200, body: {'wrong': url}));
      await expectLater(
        ShopLogoRepositoryImpl(stubClient(malformed)).fetch(scope),
        throwsA(isA<ContractFailure>()),
      );
      final absent = StubAdapter((_) => (status: 204, body: null));
      expect(
        await ShopLogoRepositoryImpl(stubClient(absent)).fetch(scope),
        isNull,
      );
    },
  );
  test('logo timeout uses the shared friendly NetworkFailure mapper', () async {
    final timeout = StubAdapter(
      (request) => throw DioException(
        requestOptions: request,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    await expectLater(
      ShopLogoRepositoryImpl(stubClient(timeout)).fetch(scope),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
