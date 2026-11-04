/// A preference is never membership or authorization.
abstract interface class SalonPreferenceRepository {
  Future<int?> read(String account);
  Future<void> write(String account, int shopId, bool Function() isCurrent);
}
