import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum BrandBackgroundKind {
  header,
  operations,
  dashboard,
  dashboardIcon,
  offers,
  credits,
  membership,
  services,
  shopUsers,
  shopSettings,
}

/// Paints CSS-angle gradients using actual layout dimensions, including text
/// expansion. Rounded backgrounds never impose a fixed height on their content.
class BrandBackground extends StatelessWidget {
  const BrandBackground({super.key, required this.kind, required this.child});
  final BrandBackgroundKind kind;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BrandPainter(kind), child: child);
}

class _BrandPainter extends CustomPainter {
  const _BrandPainter(this.kind);
  final BrandBackgroundKind kind;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final header = kind == BrandBackgroundKind.header;
    final gradient = switch (kind) {
      BrandBackgroundKind.header => AppTokens.homeHeaderGradient(size),
      BrandBackgroundKind.operations => AppTokens.tileGradient(
        size,
        operations: true,
      ),
      BrandBackgroundKind.dashboard => AppTokens.tileGradient(
        size,
        operations: false,
      ),
      BrandBackgroundKind.dashboardIcon => AppTokens.homeDashboardIconGradient(
        size,
      ),
      BrandBackgroundKind.offers => AppTokens.webTileGradient(size, [
        AppTokens.offersStart,
        AppTokens.offersEnd,
      ]),
      BrandBackgroundKind.credits => AppTokens.webTileGradient(size, [
        AppTokens.creditsStart,
        AppTokens.creditsEnd,
      ]),
      BrandBackgroundKind.membership => AppTokens.webTileGradient(size, [
        AppTokens.membershipStart,
        AppTokens.membershipEnd,
      ]),
      BrandBackgroundKind.services => AppTokens.webTileGradient(size, [
        AppTokens.servicesStart,
        AppTokens.servicesEnd,
      ]),
      BrandBackgroundKind.shopUsers => AppTokens.webTileGradient(size, [
        AppTokens.shopUsersStart,
        AppTokens.shopUsersEnd,
      ]),
      BrandBackgroundKind.shopSettings => AppTokens.webTileGradient(size, [
        AppTokens.shopSettingsStart,
        AppTokens.shopSettingsEnd,
      ]),
    };
    final radius = BorderRadius.circular(
      kind == BrandBackgroundKind.dashboardIcon
          ? AppTokens.homeCardIconRadius
          : AppTokens.homeTileRadius,
    );
    final shape = header
        ? const BorderRadius.vertical(
            bottom: Radius.circular(AppTokens.homeHeaderRadius),
          )
        : radius;
    canvas.drawRRect(
      shape.toRRect(Offset.zero & size),
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BrandPainter oldDelegate) => oldDelegate.kind != kind;
}
