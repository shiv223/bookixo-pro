import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';

/// Brand lockup stays above the form, wrapping at larger text scales.
class LoginBranding extends StatelessWidget {
  const LoginBranding({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        AppAssets.brandLogo,
        width: AppTokens.logoSize,
        height: AppTokens.logoSize,
        excludeFromSemantics: true,
      ),
      const SizedBox(height: AppTokens.gap),
      Text(
        AppStrings.appName,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: AppTokens.white),
      ),
      const SizedBox(height: AppTokens.smallGap),
      Text(
        AppStrings.loginSubtitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppTokens.white.withValues(alpha: AppTokens.subtitleOpacity),
          fontSize: AppTokens.subtitleSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Decorative original salon tools; omitted while the keyboard is visible.
class LoginToolsIllustration extends StatelessWidget {
  const LoginToolsIllustration({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: AppTokens.illustrationOpacity,
      child: SvgPicture.asset(
        AppAssets.loginTools,
        width: AppTokens.illustrationWidth,
        height: AppTokens.illustrationHeight,
      ),
    ),
  );
}
