import '../../../core/errors/app_failure.dart';
import '../domain/shop_user.dart';

/// Whitelists only directory display fields. Never retains the raw response.
abstract final class ShopUsersDto {
  static ShopUsersPage page(Object? raw, int requestedPage, int shopId) {
    if (raw is! Map<String, Object?>) throw const ContractFailure();
    final content = raw['content'];
    final number = raw['number'];
    final size = raw['size'];
    final total = raw['totalElements'];
    final pages = raw['totalPages'];
    final last = raw['last'];
    if (content is! List ||
        number is! int ||
        number != requestedPage ||
        size is! int ||
        size != 20 ||
        total is! int ||
        total < content.length ||
        pages is! int ||
        pages < 0 ||
        last is! bool ||
        last != (number + 1 >= pages) ||
        content.length > size ||
        (pages == 0 && (content.isNotEmpty || total != 0 || number != 0))) {
      throw const ContractFailure();
    }
    return ShopUsersPage(
      users: [for (final value in content) _user(value, shopId)],
      number: number,
      size: size,
      totalElements: total,
      totalPages: pages,
      last: last,
    );
  }

  static ShopUser _user(Object? raw, int shopId) {
    if (raw is! Map<String, Object?>) throw const ContractFailure();
    final id = raw['shopUserId'];
    final shop = raw['shopId'];
    final email = raw['email'];
    final role = raw['role'];
    final name = raw['name'];
    final phone = raw['phoneNumber'];
    final active = raw['active'];
    if (id is! int ||
        id <= 0 ||
        shop is! int ||
        shop != shopId ||
        email is! String ||
        email.trim().isEmpty ||
        role is! String ||
        role.trim().isEmpty ||
        (name != null && name is! String) ||
        (phone != null && phone is! String) ||
        (active != null && active is! bool)) {
      throw const ContractFailure();
    }
    return ShopUser(
      shopUserId: id,
      shopId: shop,
      email: email,
      role: role,
      name: name as String?,
      phoneNumber: phone as String?,
      active: active as bool?,
    );
  }
}
