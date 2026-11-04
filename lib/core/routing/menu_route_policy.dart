import '../../features/menu/presentation/menu_projection.dart';

/// All feature URLs are mobile-owned and checked before building a screen.
abstract final class MenuRoutePolicy {
  static String? redirect(Uri uri, MenuProjection projection) {
    final path = uri.path;
    if (path == '/home' && projection.landing == '/home') return null;
    if (path == '/no-access' && projection.tiles.isEmpty) return null;
    final guardedPath = path.startsWith('/queue/')
        ? '/queue'
        : path.startsWith('/web/offers/')
        ? '/web/offers'
        : path.startsWith('/dashboard/')
        ? '/dashboard'
        : path;
    if (!projection.permits(guardedPath)) return projection.landing;
    if (path == '/queue') {
      final tab = uri.queryParameters['tab'];
      if (tab != null &&
          !projection.tabs.any((allowed) => allowed.selector == tab)) {
        return '/queue?tab=${projection.tabs.first.selector}';
      }
    }
    return null;
  }
}
