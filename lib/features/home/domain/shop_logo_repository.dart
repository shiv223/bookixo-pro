import '../../menu/domain/menu_snapshot.dart';
import 'shop_logo.dart';

/// Null means confirmed absence (204), never a failed request.
abstract interface class ShopLogoRepository {
  Future<ShopLogo?> fetch(MenuScope scope);
}
