import 'mobile_menu_registry.dart';

/// Pure exact-key intersection. No role or active metadata filtering.
class MenuProjection {
  MenuProjection(Set<String> keys, {Set<String> shopSetupChildren = const {}})
    : setupChildren = Set.unmodifiable(
        keys.contains('shop-setup')
            ? shopSetupChildren.where(keys.contains)
            : const <String>{},
      ),
      tiles = List.unmodifiable(
        MobileMenuRegistry.tiles
            .where((tile) => tile.keys.any(keys.contains))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
      ),
      tabs = List.unmodifiable([
        for (final tile in MobileMenuRegistry.tiles)
          for (final tab in tile.tabs)
            if (keys.contains(tab.key)) tab,
      ]);
  final List<MobileTileDefinition> tiles;
  final List<QueueTabDefinition> tabs;
  final Set<String> setupChildren;
  String get landing => tiles.isEmpty
      ? '/no-access'
      : tiles.length == 1 && tiles.single.tabs.isNotEmpty
      ? tiles.single.route
      : '/home';
  bool permits(String route) {
    if (route.startsWith('/shop-settings/')) {
      return ShopSetupRegistry.children.any(
        (child) => child.route == route && setupChildren.contains(child.key),
      );
    }
    return tiles.any(
      (tile) =>
          tile.route == route ||
          (tile.keys.contains('shopdashboard') &&
              route.startsWith('${tile.route}/')),
    );
  }
}
