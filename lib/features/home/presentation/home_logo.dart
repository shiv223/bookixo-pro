import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/shop_logo.dart';
import 'shop_logo_controller.dart';

/// Built-in external image transport has no protected-client headers.
class HomeLogo extends ConsumerWidget {
  const HomeLogo({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shopLogoControllerProvider);
    final logo = state.isLoading ? null : state.asData?.value;
    return SizedBox(
      width: AppTokens.homeLogo,
      height: AppTokens.homeLogo,
      child: logo == null
          ? const DefaultHomeLogo()
          : RemoteHomeLogo(key: ObjectKey(logo), logo: logo),
    );
  }
}

class DefaultHomeLogo extends StatelessWidget {
  const DefaultHomeLogo({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.brandLogo,
    fit: BoxFit.cover,
    width: AppTokens.homeLogo,
    height: AppTokens.homeLogo,
    semanticLabel: AppStrings.appName,
  );
}

/// A frame-local failure is reported once, outside the widget build phase.
class RemoteHomeLogo extends ConsumerStatefulWidget {
  const RemoteHomeLogo({super.key, required this.logo});
  final ShopLogo logo;
  @override
  ConsumerState<RemoteHomeLogo> createState() => _RemoteHomeLogoState();
}

class _RemoteHomeLogoState extends ConsumerState<RemoteHomeLogo> {
  bool _reported = false;
  @override
  Widget build(BuildContext context) => Image.network(
    widget.logo.url.toString(),
    headers: const {},
    width: AppTokens.homeLogo,
    height: AppTokens.homeLogo,
    fit: BoxFit.cover,
    semanticLabel: AppStrings.shopLogo,
    frameBuilder: (context, child, frame, synchronous) =>
        synchronous || frame != null ? child : const DefaultHomeLogo(),
    errorBuilder: (context, error, stack) {
      if (!_reported) {
        _reported = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(shopLogoControllerProvider.notifier)
              .imageFailed(widget.logo, error, stack);
        });
      }
      return const DefaultHomeLogo();
    },
  );
}

/// Logo failures are nonblocking and do not alter menu/route access.
class HomeLogoNotice extends ConsumerWidget {
  const HomeLogoNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shopLogoControllerProvider);
    if (state.isLoading || state.error is! AppFailure) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.homeTileGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.logoUnavailable),
          TextButton(
            onPressed: () =>
                ref.read(shopLogoControllerProvider.notifier).refresh(),
            child: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}
