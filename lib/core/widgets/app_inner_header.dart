import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_strings.dart';
import '../theme/app_tokens.dart';
import 'shop_header_title.dart';

/// Canonical compact feature header. Place above an Expanded screen body.
///
/// Trailing content moves below the title on narrow or large-text layouts.
/// [onBack] preserves feature-specific navigation; otherwise the router pops
/// the previous route or uses [fallbackRoute] for a direct/root entry.
class AppInnerHeader extends StatelessWidget {
  const AppInnerHeader({
    required this.title,
    this.trailing,
    this.showBack = true,
    this.onBack,
    this.fallbackRoute = '/home',
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: AppTokens.transparent,
    ),
    child: CustomPaint(
      painter: const _InnerHeaderPainter(),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.innerHeaderHorizontal,
              AppTokens.innerHeaderTop,
              AppTokens.innerHeaderHorizontal,
              AppTokens.innerHeaderBottom,
            ),
            child: _InnerHeaderContent(header: this),
          ),
        ),
      ),
    ),
  );
}

class _InnerHeaderContent extends StatelessWidget {
  const _InnerHeaderContent({required this.header});

  final AppInnerHeader header;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final trailing = header.trailing;
      final stacked =
          constraints.maxWidth < AppTokens.innerHeaderStackWidth ||
          MediaQuery.textScalerOf(context).scale(1) > AppTokens.homeLargeText;
      return IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: AppTokens.white,
            minimumSize: const Size(AppTokens.target, AppTokens.target),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppTokens.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (header.showBack) ...[
                    _InnerHeaderBackButton(header: header),
                    const SizedBox(width: AppTokens.innerHeaderGap),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: ShopHeaderTitle(
                        title: header.title,
                        style: const TextStyle(
                          color: AppTokens.white,
                          fontSize: AppTokens.innerHeaderTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null && !stacked) ...[
                    const SizedBox(width: AppTokens.innerHeaderGap),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            constraints.maxWidth *
                            AppTokens.innerHeaderTrailingFraction,
                      ),
                      child: trailing,
                    ),
                  ],
                ],
              ),
              if (trailing != null && stacked) ...[
                const SizedBox(height: AppTokens.innerHeaderGap),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _InnerHeaderBackButton extends StatelessWidget {
  const _InnerHeaderBackButton({required this.header});
  final AppInnerHeader header;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppStrings.back,
    onPressed:
        header.onBack ??
        () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(header.fallbackRoute);
          }
        },
    style: IconButton.styleFrom(
      minimumSize: const Size(AppTokens.target, AppTokens.target),
      backgroundColor: AppTokens.white.withValues(
        alpha: AppTokens.innerHeaderTranslucency,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      ),
    ),
    icon: const Icon(Icons.arrow_back),
  );
}

/// Translucent, wrapping badge for a compact header's trailing slot.
class AppInnerHeaderBadge extends StatelessWidget {
  const AppInnerHeaderBadge({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: AppTokens.target),
    padding: const EdgeInsets.all(AppTokens.smallGap),
    decoration: BoxDecoration(
      color: AppTokens.white.withValues(
        alpha: AppTokens.innerHeaderTranslucency,
      ),
      borderRadius: BorderRadius.circular(AppTokens.controlRadius),
    ),
    child: Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        label,
        style: const TextStyle(
          color: AppTokens.white,
          fontSize: AppTokens.innerHeaderBadgeSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _InnerHeaderPainter extends CustomPainter {
  const _InnerHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const radius = BorderRadius.vertical(
      bottom: Radius.circular(AppTokens.innerHeaderRadius),
    );
    canvas.drawRRect(
      radius.toRRect(Offset.zero & size),
      Paint()
        ..shader = AppTokens.homeHeaderGradient(size)
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_InnerHeaderPainter oldDelegate) => false;
}
