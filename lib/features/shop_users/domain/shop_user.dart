/// Minimal in-memory directory record; no identity-provider metadata or prices.
class ShopUser {
  const ShopUser({
    required this.shopUserId,
    required this.shopId,
    required this.email,
    required this.role,
    this.name,
    this.phoneNumber,
    this.active,
  });
  final int shopUserId;
  final int shopId;
  final String email;
  final String role;
  final String? name;
  final String? phoneNumber;
  final bool? active;
  String get displayName {
    final value = name?.trim();
    return value == null || value.isEmpty ? email : value;
  }
}

class ShopUsersPage {
  ShopUsersPage({
    required List<ShopUser> users,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  }) : users = List.unmodifiable(users);
  final List<ShopUser> users;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
  bool get hasNext => !last && number + 1 < totalPages;
}
