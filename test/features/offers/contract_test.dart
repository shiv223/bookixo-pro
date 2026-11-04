import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/network/auth_interceptor.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/offers/data/offers_dto.dart';
import 'package:bookixo_pro/features/offers/data/offers_repository_impl.dart';
import 'package:bookixo_pro/features/offers/data/mock_offers_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../home/logo_repository_test.dart' show LogoSession;

Map<String, Object?> offerJson({int id = 1}) => {
  'id': id,
  'shopId': 15,
  'shopName': 'Fuzion',
  'title': 'BINGO DISCOUNT',
  'description': 'asdasda',
  'discountType': 'FLAT',
  'discountValue': 50.00,
  'priority': 0,
  'stackable': true,
  'startDate': '2026-02-17',
  'endDate': '2027-02-26',
  'isActive': true,
};
Map<String, Object?> targetJson({int id = 1}) => {
  'id': id,
  'offerId': 1,
  'targetType': 'SHOP',
  'serviceMatchMode': null,
  'isCombo': false,
  'targetIds': <int>[],
  'targetNames': <String>[],
  'hasAnotherOfferForSameService': false,
};
Map<String, Object?> ruleJson({int id = 1}) => {
  'id': id,
  'offerId': 1,
  'scheduleType': 'WEEKLY',
  'dayOfWeek': 1,
  'dayOfMonth': null,
  'specificDate': null,
  'startTime': '00:00:00',
  'endTime': '23:59:59',
  'isActive': false,
};
Map<String, Object?> pageJson(
  List<Object?> content, {
  int page = 0,
  bool last = true,
}) => {
  'content': content,
  'number': page,
  'size': 100,
  'totalElements': content.length,
  'totalPages': last ? page + 1 : 10,
  'last': last,
};

void main() {
  const scope = MenuScope('5', 'subject', 15);
  test('demo exposes read-only offer, target and full rule fixtures', () async {
    final repo = MockOffersRepository();
    final original = (await repo.rules(scope, 0)).content.single;
    expect(original.isActive, true);
    expect(original.scheduleType, 'ALWAYS');
    expect(original.startTime, '00:00:00');
    expect((await repo.targets(scope, 0)).content.single.eligible, true);
    expect((await repo.offers(scope, 0)).content.single.isActive, true);
    expect(
      (await repo.rules(
        const MenuScope('6', 'other', 15),
        0,
      )).content.single.isActive,
      true,
    );
  });
  test(
    'confirmed offer fixture ignores metadata and absent validity is explicit',
    () {
      final offer = OffersDto.offer(offerJson());
      expect(offer.title, 'BINGO DISCOUNT');
      expect(offer.discountValue, 50);
      expect(offer.validDates, true);
      for (final date in [null, '2026-02-30', '2026-10-08T00:00:00Z']) {
        expect(
          OffersDto.offer({...offerJson(), 'startDate': date}).validDates,
          false,
        );
      }
      expect(
        OffersDto.offer({...offerJson(), 'discountType': 'UNKNOWN'})
            .knownDiscount,
        false,
      );
      expect(
        () => OffersDto.offer({...offerJson(), 'discountValue': '50'}),
        throwsA(isA<ContractFailure>()),
      );
    },
  );
  test('array target contract ignores singular metadata and preserves unknown mode', () {
    final target = OffersDto.target({
      ...targetJson(),
      'targetType': 'SERVICE',
      'targetNames': [' Hair Cut ', '', 'Hair Spa'],
      'targetIds': [10, 11],
      'targetName': 'IGNORED',
      'targetId': 999,
      'serviceMatchMode': 'OTHER',
    });
    expect(target.targetNames, ['Hair Cut', 'Hair Spa']);
    expect(target.serviceMatchMode, 'OTHER');
    expect(OffersDto.target(targetJson()).eligible, true);
    expect(
      OffersDto.target({...targetJson(), 'targetType': 'SERVICE'}).eligible,
      false,
    );
    expect(
      OffersDto.target({...targetJson(), 'targetType': 'OTHER'}).eligible,
      false,
    );
  });
  test('strict Spring page metadata and resource structure', () {
    for (final patch in <Map<String, Object?>>[
      {'content': null},
      {'number': 1},
      {'last': null},
      {'size': 20},
      {'totalPages': null},
      {'totalElements': -1},
    ]) {
      expect(
        () => OffersDto.page({...pageJson([]), ...patch}, 0, OffersDto.offer),
        throwsA(isA<ContractFailure>()),
      );
    }
    expect(
      () => OffersDto.rule({...ruleJson(), 'dayOfWeek': 'Sunday'}),
      throwsA(isA<ContractFailure>()),
    );
    final rule = OffersDto.rule(ruleJson());
    expect(rule.isActive, false);
    expect(rule.source['startTime'], '00:00:00');
  });
  test(
    'all three GET endpoints use ACCESS and required shop/page/size, no writes',
    () async {
      final session = LogoSession();
      final adapter = StubAdapter(
        (request) => (
          status: 200,
          body: pageJson([
            if (request.path == 'api/shop-offers') offerJson(),
            if (request.path == 'api/offer-targets') targetJson(),
            if (request.path == 'api/offer-schedule-rules') ruleJson(),
          ], page: request.queryParameters['page'] as int),
        ),
      );
      final client = stubClient(adapter);
      client.interceptors.add(AuthInterceptor(client, session, FakeClock()));
      final repo = OffersRepositoryImpl(client);
      await Future.wait([
        repo.offers(scope, 0),
        repo.targets(scope, 4),
        repo.rules(scope, 9),
      ]);
      expect(adapter.requests.map((r) => r.path), [
        'api/shop-offers',
        'api/offer-targets',
        'api/offer-schedule-rules',
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.queryParameters['shopId'], 15);
        expect(request.queryParameters['size'], 100);
        expect(request.headers['Authorization'], isNotNull);
        expect(request.extra[AuthInterceptor.safeRead], true);
      }
      expect(adapter.requests.map((r) => r.queryParameters['page']), [0, 4, 9]);
    },
  );
  test('invalid shop/page rejected before any transport', () async {
    final adapter = StubAdapter((_) => (status: 200, body: pageJson([])));
    final repo = OffersRepositoryImpl(stubClient(adapter));
    for (final bad in [
      const MenuScope('', null, 15),
      const MenuScope('5', null, 0),
    ]) {
      await expectLater(repo.offers(bad, 0), throwsA(isA<ContractFailure>()));
      await expectLater(repo.targets(bad, 0), throwsA(isA<ContractFailure>()));
      await expectLater(repo.rules(bad, 0), throwsA(isA<ContractFailure>()));
    }
    await expectLater(repo.offers(scope, 10), throwsA(isA<ContractFailure>()));
    expect(adapter.requests, isEmpty);
  });
  test(
    '401 refresh/logout remains bounded; 403 and timeout stay typed',
    () async {
      final session = LogoSession();
      final adapter = StubAdapter((_) => (status: 401, body: null));
      final client = stubClient(adapter);
      client.interceptors.add(AuthInterceptor(client, session, FakeClock()));
      await expectLater(
        OffersRepositoryImpl(client).offers(scope, 0),
        throwsA(isA<UnauthorizedFailure>()),
      );
      expect(adapter.requests, hasLength(2));
      expect(session.renewals, 1);
      expect(session.logouts, 1);
      final denied = StubAdapter((_) => (status: 403, body: null));
      await expectLater(
        OffersRepositoryImpl(stubClient(denied)).targets(scope, 0),
        throwsA(isA<ForbiddenFailure>()),
      );
      final timeout = StubAdapter(
        (request) => throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await expectLater(
        OffersRepositoryImpl(stubClient(timeout)).rules(scope, 0),
        throwsA(isA<NetworkFailure>()),
      );
    },
  );
}
