/// Feature keys the server has enabled for the selected shop, such as
/// `SHOP_BOOKINGS_CREATE`.
abstract interface class ShopFeaturesRepository {
  Future<Set<String>> loadEnabledFeatures(int shopId);
}
