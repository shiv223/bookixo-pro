import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../../core/widgets/feature_message.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/mobile_menu_registry.dart';

/// Child tiles come only from the current snapshot's immediate Setup edges.
class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref
        .watch(menuControllerProvider)
        .asData
        ?.value
        ?.projection;
    final children = ShopSetupRegistry.children
        .where((child) => projection?.permits(child.route) == true)
        .toList();
    return Scaffold(
      body: Column(
        children: [
          const AppInnerHeader(title: AppStrings.shopSettings),
          Expanded(
            child: children.isEmpty
                ? const FeatureMessage(message: AppStrings.shopSettingsEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.all(AppTokens.homeInset),
                    itemCount: children.length,
                    itemBuilder: (context, index) {
                      final child = children[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(child.icon),
                          title: Text(child.title),
                          subtitle: const Text(AppStrings.availableOnWeb),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(child.route),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// No configuration API, external URL or browser action is inferred.
class ShopSettingInformationScreen extends StatelessWidget {
  const ShopSettingInformationScreen({super.key, required this.destination});
  final ShopSetupDestination destination;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        AppInnerHeader(
          title: destination.title,
          fallbackRoute: '/shop-settings',
        ),
        const Expanded(
          child: FeatureMessage(
            message:
                '${AppStrings.availableOnWeb}\n\n${AppStrings.settingsWebBody}',
          ),
        ),
      ],
    ),
  );
}
