import 'package:bookixo_pro/features/auth/domain/role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final alias in ['OWNER', 'shop_admin', 'shop_owner']) {
    test('$alias wins over employee and unknown groups', () {
      expect(
        RolePolicy.derive([alias, 'shop_employee', 'other']),
        AppRole.owner,
      );
    });
  }
  test('employee is exact and unknown is restricted', () {
    expect(RolePolicy.derive(['shop_employee', 'other']), AppRole.employee);
    for (final groups in [
      <String>[],
      ['owner'],
      ['SHOP_EMPLOYEE'],
      ['other'],
    ]) {
      expect(RolePolicy.derive(groups), AppRole.unknown);
    }
  });
}
