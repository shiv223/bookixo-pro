import '../../../core/time/session_clock.dart';
import '../domain/menu_repository.dart';
import '../domain/menu_snapshot.dart';
import 'menu_response_dto.dart';

/// Explicit demo response; excludes customer creation and attendance.
class MockMenuRepository implements MenuRepository {
  MockMenuRepository(this.clock);
  final SessionClock clock;
  static const demoKeys = [
    'bookings-pending',
    'bookings-in-progress',
    'shopdashboard',
    'shop-offers-2',
    'shop-credits-packages',
    'shop-memberships',
    'shop-services-list',
    'users-shop',
    'shop-setup',
  ];
  MenuSnapshot? _cache;
  @override
  Future<MenuSnapshot> fetch(MenuScope scope) async {
    final dto = MenuResponseDto.parse([
      for (final key in demoKeys)
        {
          'menuKey': key,
          'children': [
            if (key == 'shop-setup')
              for (final child in const [
                'workday',
                'shop-gst-settings',
                'shop-booking-qr',
                'shop-payment-config',
                'shop-logo',
              ])
                {'menuKey': child, 'children': <Object?>[]},
          ],
        },
    ]);
    return MenuSnapshot(
      scope,
      dto.keys,
      clock.now(),
      shopSetupChildren: dto.shopSetupChildren,
    );
  }

  @override
  Future<MenuSnapshot?> read(MenuScope scope) async =>
      _cache?.scope == scope ? _cache : null;
  @override
  Future<void> write(MenuSnapshot snapshot, bool Function() current) async {
    if (current()) _cache = snapshot;
  }

  @override
  Future<void> clear() async {
    _cache = null;
  }
}
