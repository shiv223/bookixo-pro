import '../../../core/errors/app_failure.dart';
import '../domain/shop_context.dart';

/// Strict confirmed context mapping; inconsistent primary is not a fallback.
class ShopContextDto {
  const ShopContextDto._(this.json);
  final Map<String, Object?> json;
  static ShopContextDto parse(Object? value) {
    if (value is! Map<String, Object?>) throw const ContractFailure();
    return ShopContextDto._(value);
  }

  ShopContext toDomain() {
    final raw = json['shops'];
    if (raw is! List) throw const ContractFailure();
    final shops = <Shop>[];
    for (final item in raw) {
      if (item is! Map<String, Object?>) throw const ContractFailure();
      final id = item['id'];
      final name = item['name'];
      if (id is! int ||
          id <= 0 ||
          name is! String ||
          name.trim().isEmpty ||
          shops.any((shop) => shop.id == id)) {
        throw const ContractFailure();
      }
      shops.add(Shop(id, name));
    }
    if (shops.isEmpty) return ShopContext(shops, null);
    final id = json['primaryShopId'];
    final name = json['primaryShopName'];
    if (id is! int ||
        name is! String ||
        !shops.any((shop) => shop.id == id && shop.name == name)) {
      throw const ContractFailure();
    }
    return ShopContext(shops, id);
  }
}
