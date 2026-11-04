/// Display hints only. Every API operation remains server-authorized.
enum AppRole { owner, employee, unknown }

/// Ordered and centralized display group mapping, not navigation permissions.
abstract final class RolePolicy {
  static const rules = [
    (groups: {'OWNER', 'shop_admin', 'shop_owner'}, role: AppRole.owner),
    (groups: {'shop_employee'}, role: AppRole.employee),
  ];
  static AppRole derive(Iterable<String> groups) {
    for (final rule in rules) {
      if (groups.any(rule.groups.contains)) return rule.role;
    }
    return AppRole.unknown;
  }

  static bool supports(AppRole role) => role != AppRole.unknown;
}
