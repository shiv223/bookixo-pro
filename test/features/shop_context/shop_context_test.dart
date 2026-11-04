import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/shop_context/data/shop_context_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty context blocks; primary must be returned member', () {
    expect(ShopContextDto.parse({'shops': []}).toDomain().shops, isEmpty);
    final json = {
      'shops': [
        {'id': 15, 'name': 'Sample shop'},
      ],
      'primaryShopId': 15,
      'primaryShopName': 'Sample shop',
    };
    expect(ShopContextDto.parse(json).toDomain().primaryShopId, 15);
    expect(
      () => ShopContextDto.parse({...json, 'primaryShopId': 99}).toDomain(),
      throwsA(isA<ContractFailure>()),
    );
    expect(
      () =>
          ShopContextDto.parse({...json, 'primaryShopName': 'Wrong'})
              .toDomain(),
      throwsA(isA<ContractFailure>()),
    );
  });
  test('malformed and duplicate shops do not fabricate empty success', () {
    for (final json in [
      <String, Object?>{},
      {'shops': 'bad'},
      {
        'shops': [
          {'id': '15', 'name': 'Shop'},
        ],
      },
      {
        'shops': [
          {'id': 1, 'name': 'A'},
          {'id': 1, 'name': 'B'},
        ],
      },
    ]) {
      expect(
        () => ShopContextDto.parse(json).toDomain(),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
}
