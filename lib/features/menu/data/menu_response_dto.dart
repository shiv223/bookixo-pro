import '../../../core/errors/app_failure.dart';

/// Strict confirmed array contract; web metadata has no mobile authority.
class MenuResponseDto {
  MenuResponseDto._(this.keys, this.shopSetupChildren);
  final Set<String> keys;
  final Set<String> shopSetupChildren;
  static MenuResponseDto parse(Object? response) {
    if (response is! List) throw const ContractFailure();
    final keys = <String>{};
    final setupChildren = <String>{};
    void visit(Object? value, {String? parent, int depth = 0}) {
      if (depth > 64) throw const ContractFailure();
      if (value is! Map<String, Object?>) throw const ContractFailure();
      final key = value['menuKey'];
      final children = value['children'];
      if (key is! String || key.trim().isEmpty || children is! List) {
        throw const ContractFailure();
      }
      keys.add(key);
      if (parent == 'shop-setup') setupChildren.add(key);
      for (final child in children) {
        visit(child, parent: key, depth: depth + 1);
      }
    }

    for (final root in response) {
      visit(root);
    }
    return MenuResponseDto._(
      Set.unmodifiable(keys),
      Set.unmodifiable(setupChildren),
    );
  }
}
