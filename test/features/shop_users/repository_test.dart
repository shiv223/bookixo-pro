import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/shop_users/data/shop_users_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/fakes.dart';

// Entirely synthetic contact fixture. Never copy production directory records.
Map<String, Object?> userRow({int shopId = 15}) => {
  'shopUserId': 1,
  'shopId': shopId,
  'shopName': 'Example salon',
  'role': 'SHOP_EMPLOYEE',
  'assignedAt': '2026-01-01T00:00:00Z',
  'userId': 2,
  'email': 'staff@example.test',
  'name': null,
  'phoneNumber': null,
  'active': null,
};

Map<String, Object?> usersPage({
  List<Object?>? content,
  int number = 0,
  int totalPages = 1,
  bool last = true,
}) => {
  'content': content ?? [userRow()],
  'number': number,
  'size': 20,
  'totalElements': totalPages == 1 ? 1 : 21,
  'totalPages': totalPages,
  'last': last,
};

void main() {
  const scope = MenuScope('account', null, 15);
  test('protected directory read uses ACCESS token and bounded 401 recovery', () async {
    final clock = FakeClock();
    final auth = FakeAuthRepository()
      ..restored = sampleSession()
      ..refreshResult = Authenticated(sampleSession(salt: 'renewed'));
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    var calls = 0;
    final client = stubClient(
      StubAdapter((request) {
        expect(
          request.headers['Authorization'],
          'Bearer ${sampleSession(salt: calls == 0 ? 'a' : 'renewed').tokens.accessToken}',
        );
        return (status: ++calls == 1 ? 401 : 200, body: usersPage());
      }),
    );
    addTearDown(client.close);
    client.interceptors.add(
      AuthInterceptor(
        client,
        container.read(authControllerProvider.notifier),
        clock,
      ),
    );
    expect(
      (await ShopUsersRepositoryImpl(client).load(scope, 0)).users.length,
      1,
    );
    expect(auth.renewals, 1);
    expect(calls, 2);
  });
  test(
    'confirmed GET uses Dio query parameters, safe read and minimal DTO',
    () async {
      final adapter = StubAdapter((request) {
        expect(request.method, 'GET');
        expect(request.path, 'api/users/shop-users');
        expect(request.queryParameters, {
          'shopIds': 15,
          'page': 0,
          'size': 20,
          'sort': 'id,desc',
        });
        expect(request.extra[AuthInterceptor.safeRead], isTrue);
        return (status: 200, body: usersPage());
      });
      final client = stubClient(adapter);
      addTearDown(client.close);
      final page = await ShopUsersRepositoryImpl(client).load(scope, 0);
      final user = page.users.single;
      expect(user.displayName, 'staff@example.test');
      expect(user.phoneNumber, isNull);
      expect(user.active, isNull);
      expect(page.last, isTrue);
    },
  );

  test(
    'short and empty non-last pages still permit loading the next page',
    () async {
      final client = stubClient(
        StubAdapter(
          (_) => (
            status: 200,
            body: usersPage(content: [], totalPages: 2, last: false),
          ),
        ),
      );
      addTearDown(client.close);
      final page = await ShopUsersRepositoryImpl(client).load(scope, 0);
      expect(page.last, isFalse);
      expect(page.number + 1, lessThan(page.totalPages));
    },
  );

  test('invalid scope is rejected before transport', () async {
    final adapter = StubAdapter((_) => (status: 200, body: usersPage()));
    final client = stubClient(adapter);
    addTearDown(client.close);
    final repo = ShopUsersRepositoryImpl(client);
    for (final invalid in [
      const MenuScope('account', null, 0),
      const MenuScope('', null, 15),
    ]) {
      await expectLater(repo.load(invalid, 0), throwsA(isA<ContractFailure>()));
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'malformed consumed fields and cross-shop rows are typed failures',
    () async {
      for (final response in [
        null,
        <String, Object?>{},
        usersPage(content: [userRow(shopId: 16)]),
        usersPage(
          content: [
            {...userRow(), 'active': 'yes'},
          ],
        ),
        usersPage(
          content: [
            {...userRow(), 'phoneNumber': 123},
          ],
        ),
        {...usersPage(), 'number': 1},
        {...usersPage(), 'last': false},
        {...usersPage(), 'size': '20'},
      ]) {
        final client = stubClient(
          StubAdapter((_) => (status: 200, body: response)),
        );
        await expectLater(
          ShopUsersRepositoryImpl(client).load(scope, 0),
          throwsA(isA<ContractFailure>()),
        );
        client.close();
      }
    },
  );

  for (final status in [401, 403, 500]) {
    test('HTTP $status becomes a sanitized typed failure', () async {
      final client = stubClient(StubAdapter((_) => (status: status, body: {})));
      addTearDown(client.close);
      await expectLater(
        ShopUsersRepositoryImpl(client).load(scope, 0),
        throwsA(
          status == 401
              ? isA<UnauthorizedFailure>()
              : status == 403
              ? isA<ForbiddenFailure>()
              : isA<ServerFailure>(),
        ),
      );
    });
  }
}
