import '../../menu/domain/menu_snapshot.dart';
import 'shop_user.dart';

abstract interface class ShopUsersRepository {
  Future<ShopUsersPage> load(MenuScope scope, int page);
}
