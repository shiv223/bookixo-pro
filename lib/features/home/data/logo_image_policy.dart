import 'package:flutter/painting.dart';

import '../domain/shop_logo.dart';

/// Inspect only safe typed metadata, never exception messages or URL strings.
abstract final class LogoImagePolicy {
  static bool mayHaveExpired(ShopLogo logo, Object error, DateTime now) =>
      (logo.expiresAt?.isAfter(now) == false) ||
      (error is NetworkImageLoadException && error.statusCode == 403);

  /// Evict this exact provider key only; never clear the shared image cache.
  static void evict(ShopLogo logo) => PaintingBinding.instance.imageCache.evict(
    NetworkImage(logo.url.toString()),
  );
}
