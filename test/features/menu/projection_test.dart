import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/menu/data/menu_response_dto.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_projection.dart';
import 'package:bookixo_pro/features/menu/presentation/mobile_menu_registry.dart';
import 'package:bookixo_pro/core/routing/menu_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> node(String key, [List<Object?> children = const []]) => {
  'menuKey': key,
  'children': children,
  'isActive': false,
  'roles': ['unknown'],
  'routePath': '/untrusted',
};

const sixKeys = {
  'bookings-pending',
  'bookings-in-progress',
  'shopdashboard',
  'shop-offers-2',
  'shop-credits-packages',
  'shop-memberships',
};
const nineKeys = {...sixKeys, 'shop-services-list', 'users-shop', 'shop-setup'};

void main() {
  test(
    'nine exact keys yield eight ordered tiles without changing landing',
    () {
      final projection = MenuProjection(nineKeys);
      expect(projection.tiles.length, 8);
      expect(projection.tiles.map((tile) => tile.order), [
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
      ]);
      for (final key in ['shop-services-list', 'users-shop', 'shop-setup']) {
        expect(MenuProjection({key}).landing, '/home');
        expect(MenuProjection({key.toUpperCase(), ' $key '}).tiles, isEmpty);
      }
    },
  );
  test(
    'Setup retains immediate children only, while flat membership stays exact',
    () {
      final dto = MenuResponseDto.parse([
        node('workday'), // A root alone does not grant a Setup child.
        node('shop-setup', [
          node('shop-logo'),
          node('unknown', [node('shop-payment-config')]),
        ]),
        node('other', [node('shop-gst-settings')]),
      ]);
      expect(dto.shopSetupChildren, {'shop-logo', 'unknown'});
      expect(
        dto.keys,
        containsAll(['workday', 'shop-payment-config', 'shop-gst-settings']),
      );
      final projection = MenuProjection(
        dto.keys,
        shopSetupChildren: dto.shopSetupChildren,
      );
      for (final child in ShopSetupRegistry.children) {
        expect(
          MenuRoutePolicy.redirect(Uri.parse(child.route), projection),
          child.key == 'shop-logo' ? isNull : '/home',
        );
      }
      expect(projection.permits('/shop-settings/unknown'), isFalse);
      expect(
        MenuProjection(
          {'shop-logo'},
          shopSetupChildren: {'shop-logo'},
        ).permits('/shop-settings/shop-logo'),
        isFalse,
      );
      expect(
        MenuProjection({'shop-setup', 'shop-logo'})
            .permits('/shop-settings/shop-logo'),
        isFalse,
      );
    },
  );
  test(
    'unknown parents traversed; metadata ignored; six keys give five tiles',
    () {
      final keys = MenuResponseDto.parse([
        node('unknown', sixKeys.map((key) => node(key)).toList()),
        node('bookings-pending'),
        node('add-customers'),
      ]).keys;
      final projection = MenuProjection(keys);
      expect(projection.tiles.length, 5);
      expect(projection.landing, '/home');
      expect(projection.tabs.length, 2);
      expect(projection.tiles.map((t) => t.route), [
        '/queue',
        '/dashboard',
        '/web/offers',
        '/web/credits-packages',
        '/web/membership',
      ]);
    },
  );
  test('empty, sole Operations and every other sole tile landing', () {
    expect(MenuProjection({}).landing, '/no-access');
    for (final key in sixKeys) {
      expect(
        MenuProjection({key}).landing,
        key.startsWith('bookings-') ? '/queue' : '/home',
      );
    }
    expect(
      MenuProjection({'bookings-in-progress'}).tabs.single.selector,
      'in-progress',
    );
    expect(MenuResponseDto.parse([]).keys, isEmpty);
  });
  test('malformed consumed fields fail rather than revoke', () {
    for (final value in [
      null,
      {},
      [null],
      [
        {'menuKey': '', 'children': []},
      ],
      [
        {'menuKey': 'shopdashboard'},
      ],
      [
        {'menuKey': 2, 'children': []},
      ],
      [
        {'menuKey': 'shopdashboard', 'children': null},
      ],
    ]) {
      expect(
        () => MenuResponseDto.parse(value),
        throwsA(isA<ContractFailure>()),
      );
    }
  });
  test('exact keys only, no case aliases or customer demo permissions', () {
    expect(
      MenuProjection({'SHOPDASHBOARD', 'add-customers', ' shopdashboard '})
          .tiles,
      isEmpty,
    );
  });
}
