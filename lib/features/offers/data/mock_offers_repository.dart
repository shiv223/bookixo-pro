import '../../menu/domain/menu_snapshot.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';
import 'offers_dto.dart';

/// Explicit demo only; fixtures contain only supplied contract fields.
class MockOffersRepository implements OffersRepository {
  ScheduleRule _rule() => OffersDto.rule({
    'id': 1,
    'offerId': 1,
    'scheduleType': 'ALWAYS',
    'isActive': true,
    'startTime': '00:00:00',
    'endTime': '23:59:59',
  });

  ResourcePage<T> _page<T>(List<T> items, int page) =>
      ResourcePage(page == 0 ? items : [], page, 100, items.length, 1, true);
  @override
  Future<ResourcePage<Offer>> offers(MenuScope scope, int page) async => _page([
    OffersDto.offer({
      'id': 1,
      'title': 'BINGO DISCOUNT',
      'discountType': 'FLAT',
      'discountValue': 50.00,
      'isActive': true,
      'startDate': '2026-02-17',
      'endDate': '2027-02-26',
    }),
  ], page);
  @override
  Future<ResourcePage<OfferTarget>> targets(MenuScope scope, int page) async =>
      _page([
        OffersDto.target({
          'id': 1,
          'offerId': 1,
          'targetType': 'SHOP',
          'serviceMatchMode': null,
          'isCombo': false,
          'targetIds': <int>[],
          'targetNames': <String>[],
          'hasAnotherOfferForSameService': false,
        }),
      ], page);
  @override
  Future<ResourcePage<ScheduleRule>> rules(MenuScope scope, int page) async =>
      _page([_rule()], page);
}
