import 'shop_context.dart';

abstract interface class ShopContextRepository {
  Future<ShopContext> load();
}
