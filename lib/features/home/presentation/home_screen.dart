import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_background.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/menu_screen_tools.dart';
import '../../menu/presentation/mobile_menu_registry.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../../shop_context/presentation/salon_chooser.dart';
import 'home_tile.dart';
import 'home_logo.dart';
import 'shop_logo_controller.dart';

/// Registry-driven Home; server labels, icons and routes never enter this UI.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(shopLogoControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles =
        ref.watch(menuControllerProvider).asData?.value?.projection.tiles ?? [];
    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => refreshHome(ref),
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const HomeHeader(),
              HomeBody(tiles: tiles),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notices expand the body only when needed; default cards overlap the header.
class HomeBody extends StatelessWidget {
  const HomeBody({super.key, required this.tiles});
  final List<MobileTileDefinition> tiles;

  @override
  Widget build(BuildContext context) {
    MobileTileDefinition? operations;
    final features = <MobileTileDefinition>[];
    for (final tile in tiles) {
      if (tile.background == BrandBackgroundKind.operations) {
        operations = tile;
      } else {
        features.add(tile);
      }
    }

    return Transform.translate(
      offset: const Offset(0, -AppTokens.homeOverlap),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTokens.homeWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.homeInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MenuNotice(),
                const SalonPreferenceNotice(),
                const HomeLogoNotice(),
                if (operations != null) HomeTile(tile: operations),
                if (operations != null && features.isNotEmpty)
                  const SizedBox(height: AppTokens.homeGridGap),
                if (features.isNotEmpty) HomeFeatureGrid(tiles: features),
                const SizedBox(height: AppTokens.homeGridGap),
                const HomeRefresh(),
                const SizedBox(height: AppTokens.homeInset),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the two-column threshold tied to the actual body width and text scale.
class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({super.key, required this.tiles});
  final List<MobileTileDefinition> tiles;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaledBody = MediaQuery.textScalerOf(context)
          .scale(AppTokens.homeBodySize);
      final minimumGridWidth =
          AppTokens.homeGridMinCardWidth * 2 + AppTokens.homeGridGap;
      final useTwoColumns =
          constraints.maxWidth >= minimumGridWidth &&
          scaledBody <=
              AppTokens.homeBodySize * AppTokens.homeGridTextScaleLimit;
      final rows = <Widget>[];
      if (useTwoColumns) {
        for (var index = 0; index < tiles.length; index += 2) {
          final hasSecond = index + 1 < tiles.length;
          rows.add(
            hasSecond
                ? IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: HomeTile(tile: tiles[index])),
                        const SizedBox(width: AppTokens.homeGridGap),
                        Expanded(child: HomeTile(tile: tiles[index + 1])),
                      ],
                    ),
                  )
                : HomeTile(tile: tiles[index]),
          );
          if (index + 2 < tiles.length) {
            rows.add(const SizedBox(height: AppTokens.homeGridGap));
          }
        }
      } else {
        for (var index = 0; index < tiles.length; index++) {
          rows.add(HomeTile(tile: tiles[index]));
          if (index + 1 < tiles.length) {
            rows.add(const SizedBox(height: AppTokens.homeGridGap));
          }
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    },
  );
}

/// Rounded branded header grows naturally at large text sizes.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(selectedShopProvider);
    final role = ref.watch(authControllerProvider).asData?.value.identity?.role;
    final shopLabel = AppStrings.homeShop(
      shop?.name ?? AppStrings.appName,
      role == AppRole.owner ? AppStrings.ownerRole : AppStrings.employeeRole,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppTokens.transparent,
      ),
      child: BrandBackground(
        kind: BrandBackgroundKind.header,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.homeInset,
              AppTokens.homeInset,
              AppTokens.homeInset,
              AppTokens.homeHeaderBottom,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scaledBody = MediaQuery.textScalerOf(context)
                    .scale(AppTokens.homeBodySize);
                final compact =
                    scaledBody >
                        AppTokens.homeBodySize * AppTokens.homeLargeText ||
                    constraints.maxWidth < AppTokens.homeHeaderCompactWidth;
                final profile = HomeProfile(
                  shopLabel: shopLabel,
                  selectedSalonName: shop?.name ?? AppStrings.appName,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      profile,
                      const SizedBox(height: AppTokens.homeHeaderGap),
                      const HomeLogout(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: profile),
                    const SizedBox(width: AppTokens.homeHeaderGap),
                    const HomeLogout(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The logo source can change without changing profile geometry.
class HomeProfile extends StatelessWidget {
  const HomeProfile({
    super.key,
    required this.shopLabel,
    required this.selectedSalonName,
  });
  final String shopLabel;
  final String selectedSalonName;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.controlRadius),
          border: Border.all(
            color: AppTokens.white.withValues(
              alpha: AppTokens.homeLogoBorderOpacity,
            ),
            width: AppTokens.focusOutlineWidth,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.controlRadius),
          child: const HomeLogo(),
        ),
      ),
      const SizedBox(width: AppTokens.homeHeaderGap),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.welcomeBack,
              style: homeTextStyle(
                context,
                size: AppTokens.homeWelcomeSize,
                color: AppTokens.white.withValues(
                  alpha: AppTokens.homeWelcomeOpacity,
                ),
              ),
            ),
            SalonChooser(
              homeTrigger: true,
              selectedSalonName: selectedSalonName,
              homeChild: Text(
                shopLabel,
                style: homeTextStyle(
                  context,
                  bold: true,
                  size: AppTokens.homeShopSize,
                  color: AppTokens.white,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Compact pill keeps the mockup hierarchy with an accessible minimum target.
class HomeLogout extends ConsumerWidget {
  const HomeLogout({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Tooltip(
    message: AppStrings.logout,
    child: TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: AppTokens.white,
        foregroundColor: AppTokens.darkBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.homeHeaderGap,
        ),
        shape: const StadiumBorder(),
        textStyle: homeTextStyle(
          context,
          bold: true,
          size: AppTokens.homeWelcomeSize,
        ),
      ),
      onPressed: () => ref.read(authControllerProvider.notifier).logout(),
      icon: const Icon(Icons.logout, size: AppTokens.homeWelcomeSize),
      label: const Text(AppStrings.logout),
    ),
  );
}

/// Manual refresh remains available without enlarging the profile row.
class HomeRefresh extends ConsumerWidget {
  const HomeRefresh({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(menuControllerProvider).asData?.value?.refreshing == true ||
        ref.watch(shopLogoControllerProvider).isLoading;
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        tooltip: AppStrings.refresh,
        onPressed: busy ? null : () => refreshHome(ref),
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}

/// Both independent resources refresh without serializing unrelated requests.
Future<void> refreshHome(WidgetRef ref) => Future.wait([
  ref.read(menuControllerProvider.notifier).refresh(),
  ref.read(shopLogoControllerProvider.notifier).refresh(),
]);
