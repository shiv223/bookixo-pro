import '../../menu/domain/menu_snapshot.dart';
import '../domain/shop_user.dart';
import '../domain/shop_users_repository.dart';

/// Explicit demo only, with synthetic contacts.
class MockShopUsersRepository implements ShopUsersRepository {
  const MockShopUsersRepository();
  @override
  Future<ShopUsersPage> load(MenuScope scope, int page) async => ShopUsersPage(
    users: [
      ShopUser(
        shopUserId: 1,
        shopId: scope.shopId,
        name: 'Example staff',
        email: 'staff@example.test',
        role: 'SHOP_EMPLOYEE',
        active: true,
      ),
    ],
    number: page,
    size: 20,
    totalElements: 1,
    totalPages: 1,
    last: true,
  );
}
