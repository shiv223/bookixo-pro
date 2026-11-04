import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_background.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../menu/presentation/mobile_menu_registry.dart';
import 'home_tile_icon.dart';

/// Presents registry-driven Home cards without changing their routes or keys.
class HomeTile extends ConsumerWidget {
  const HomeTile({super.key, required this.tile});
  final MobileTileDefinition tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOperations = tile.background == BrandBackgroundKind.operations;
    final isWebOnly = tile.kind == TileKind.webOnly;

    void open() {
      if (isWebOnly || tile.keys.contains('shop-offers-2')) {
        ref.read(appLoggerProvider).upsellTile();
      }
      context.push(tile.route);
    }

    return Semantics(
      button: true,
      onTap: open,
      label: isWebOnly ? '${tile.title}, ${AppStrings.webOnly}' : tile.title,
      excludeSemantics: true,
      child: isOperations
          ? _OperationsCard(tile: tile, onTap: open)
          : _FeatureCard(tile: tile, onTap: open),
    );
  }
}

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({required this.tile, required this.onTap});
  final MobileTileDefinition tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BrandBackground(
    kind: BrandBackgroundKind.operations,
    child: Material(
      color: AppTokens.transparent,
      borderRadius: BorderRadius.circular(AppTokens.homeTileRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.homeTileRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTokens.target),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.homeTilePadding),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    tile.icon,
                    color: AppTokens.white,
                    size: AppTokens.homeOperationIconSize,
                  ),
                ),
                const SizedBox(width: AppTokens.homeOperationTextGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tile.title,
                        style: homeTextStyle(
                          context,
                          color: AppTokens.white,
                          size: AppTokens.homeTitleSize,
                          bold: true,
                        ),
                      ),
                      Text(
                        tile.subtitle,
                        style: homeTextStyle(
                          context,
                          color: AppTokens.white,
                          size: AppTokens.homeOperationSubtitleSize,
                        ),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: AppTokens.white,
                    size: AppTokens.homeOperationIconSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.tile, required this.onTap});
  final MobileTileDefinition tile;
  final VoidCallback onTap;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    final isWebOnly = tile.kind == TileKind.webOnly;
    final radius = BorderRadius.circular(AppTokens.homeCardRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BrandBackground(
        kind: tile.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTokens.white.withValues(
                alpha: AppTokens.homeCardBorderOpacity,
              ),
            ),
          ),
          child: Material(
            color: AppTokens.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onHighlightChanged: (pressed) =>
                  setState(() => _pressed = pressed),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.homeCardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeTileIcon(
                      key: ValueKey(tile.route),
                      tile: tile,
                      pressed: _pressed,
                    ),
                    const SizedBox(height: AppTokens.homeCardIconGap),
                    Text(
                      tile.title,
                      style: homeTextStyle(
                        context,
                        color: AppTokens.white,
                        size: AppTokens.homeCardTitleSize,
                        semiBold: true,
                      ),
                    ),
                    const SizedBox(height: AppTokens.homeCardTextGap),
                    if (isWebOnly)
                      const HomeWebBadge()
                    else
                      Text(
                        tile.subtitle,
                        style: homeTextStyle(
                          context,
                          color: AppTokens.white.withValues(
                            alpha: AppTokens.homeCardSubtitleOpacity,
                          ),
                          size: AppTokens.homeCardSubtitleSize,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visible text badge wraps naturally at large text sizes.
class HomeWebBadge extends StatelessWidget {
  const HomeWebBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.white,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.homeBadgeInset,
        ),
        child: Text(
          AppStrings.webOnly,
          style: homeTextStyle(
            context,
            color: AppTokens.text,
            size: AppTokens.homeCardSubtitleSize,
          ),
        ),
      ),
    );
  }
}

/// Home typography without changing other screens' Material theme.
TextStyle homeTextStyle(
  BuildContext context, {
  double size = AppTokens.homeBodySize,
  Color? color,
  bool bold = false,
  bool semiBold = false,
}) => TextStyle(
  fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
  fontSize: size,
  height: AppTokens.homeTextHeight,
  letterSpacing: 0,
  color: color,
  fontWeight: bold
      ? FontWeight.w700
      : semiBold
      ? FontWeight.w600
      : FontWeight.w400,
);
