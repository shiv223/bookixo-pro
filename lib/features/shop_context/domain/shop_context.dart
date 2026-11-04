/// Price-free shop identity. No locally inferred permissions.
class Shop {
  const Shop(this.id, this.name);
  final int id;
  final String name;
}

class ShopContext {
  ShopContext(List<Shop> shops, this.primaryShopId)
    : shops = List.unmodifiable(shops);
  final List<Shop> shops;
  final int? primaryShopId;
}
