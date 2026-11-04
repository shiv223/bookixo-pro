import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_background.dart';
import '../../menu/presentation/mobile_menu_registry.dart';

/// Home icon glyph animation never changes the tile's tap geometry.
class HomeTileIcon extends StatefulWidget {
  const HomeTileIcon({super.key, required this.tile, required this.pressed});

  final MobileTileDefinition tile;
  final bool pressed;

  @override
  State<HomeTileIcon> createState() => _HomeTileIconState();
}

class _HomeTileIconState extends State<HomeTileIcon>
    with SingleTickerProviderStateMixin {
  // Initialized once with this State's ticker and disposed with the icon.
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: AppTokens.homeIconEntranceDuration,
    );
    final progress = _entrance.drive(
      CurveTween(curve: AppTokens.homeIconMotionCurve),
    );
    _fade = progress;
    _scale = progress.drive(
      Tween(begin: AppTokens.homeIconEntranceScale, end: 1.0),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      // Finish immediately, including when the preference changes mid-entrance.
      _entrance.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.tile.icon,
      color: AppTokens.white,
      size: AppTokens.homeCardGlyphSize,
    );
    final animatedIcon = _reduceMotion
        ? icon
        : FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedScale(
                scale: widget.pressed ? AppTokens.homeIconPressScale : 1,
                duration: AppTokens.homeIconPressDuration,
                curve: AppTokens.homeIconMotionCurve,
                child: icon,
              ),
            ),
          );
    return ExcludeSemantics(
      child: _IconArtwork(tile: widget.tile, icon: animatedIcon),
    );
  }
}

class _IconArtwork extends StatelessWidget {
  const _IconArtwork({required this.tile, required this.icon});
  final MobileTileDefinition tile;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isDashboard = tile.keys.contains('shopdashboard');
    final background = switch (tile.background) {
      BrandBackgroundKind.offers =>
        dark
            ? AppTokens.homeOffersIconDarkBackground
            : AppTokens.homeOffersIconBackground,
      BrandBackgroundKind.credits =>
        dark
            ? AppTokens.homeCreditsIconDarkBackground
            : AppTokens.homeCreditsIconBackground,
      BrandBackgroundKind.membership =>
        dark
            ? AppTokens.homeMembershipIconDarkBackground
            : AppTokens.homeMembershipIconBackground,
      BrandBackgroundKind.services => AppTokens.servicesStart,
      BrandBackgroundKind.shopUsers => AppTokens.shopUsersStart,
      BrandBackgroundKind.shopSettings => AppTokens.shopSettingsStart,
      _ => theme.colorScheme.primaryContainer,
    };
    final square = SizedBox(
      width: AppTokens.homeCardIconSize,
      height: AppTokens.homeCardIconSize,
      child: Center(child: icon),
    );
    if (isDashboard) {
      return BrandBackground(
        kind: BrandBackgroundKind.dashboardIcon,
        child: square,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.homeCardIconRadius),
      ),
      child: square,
    );
  }
}
