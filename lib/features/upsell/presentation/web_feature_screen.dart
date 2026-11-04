import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../menu/presentation/menu_screen_tools.dart';
import '../../menu/presentation/mobile_menu_registry.dart';

/// Approved benefits only. No guessed URL, browser launch or credential handoff.
class WebFeatureScreen extends ConsumerWidget {
  const WebFeatureScreen({super.key, required this.tile});
  final MobileTileDefinition tile;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        AppInnerHeader(title: tile.title, trailing: const MenuActions()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.padding),
            children: [
              Icon(tile.icon, size: AppTokens.logoSize),
              const SizedBox(height: AppTokens.gap),
              const Text(AppStrings.currentlyWeb),
              for (final benefit in tile.benefits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.gap),
                  child: Text(benefit),
                ),
              const Text(AppStrings.unavailableWebBody),
              const SizedBox(height: AppTokens.gap),
              OutlinedButton(
                onPressed: () {
                  ref.read(appLoggerProvider).upsellButton();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.unavailableWebBody),
                    ),
                  );
                },
                child: const Text(AppStrings.unavailableWeb),
              ),
              const MenuNotice(),
            ],
          ),
        ),
      ],
    ),
  );
}
