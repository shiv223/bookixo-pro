import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/queue/data/shop_features_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  group('shop features', () {
    test('loads enabled keys for the selected shop', () async {
      final adapter = StubAdapter(
        (request) =>
            (status: 200, body: ['SHOP_BOOKINGS_CREATE', 'SHOP_OFFERS', '']),
      );
      final repository = ShopFeaturesRepositoryImpl(stubClient(adapter));

      final features = await repository.loadEnabledFeatures(15);

      expect(features, {'SHOP_BOOKINGS_CREATE', 'SHOP_OFFERS'});
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, 'api/shop-features/me');
      expect(request.queryParameters['shopId'], 15);
    });

    test('rejects a non-list response', () {
      expect(
        () => ShopFeaturesRepositoryImpl.parse({'features': []}),
        throwsA(isA<ContractFailure>()),
      );
    });

    test('maps server errors to typed failures', () async {
      final adapter = StubAdapter(
        (request) => (status: 500, body: {'message': 'boom'}),
      );
      final repository = ShopFeaturesRepositoryImpl(stubClient(adapter));

      await expectLater(
        repository.loadEnabledFeatures(15),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
