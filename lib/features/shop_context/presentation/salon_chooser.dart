import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import 'salon_selection_controller.dart';
import 'salon_switch_guard.dart';
import 'selected_shop_provider.dart';
import 'shop_context_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';

/// Shared header action also available on Operations-only and recovery screens.
class SalonChooser extends ConsumerWidget {
  const SalonChooser({
    super.key,
    this.homeTrigger = false,
    this.selectedSalonName,
    this.homeChild,
    this.showLabel = false,
  });

  final bool homeTrigger;
  final String? selectedSalonName;
  final Widget? homeChild;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).asData?.value.identity?.role;
    final shops = ref.watch(shopContextProvider).asData?.value?.shops ?? [];
    final guard = ref.watch(salonSwitchGuardProvider);
    if (homeTrigger) {
      final selectedName =
          selectedSalonName ?? ref.watch(selectedShopProvider)?.name ?? '';
      final display = homeChild ?? const SizedBox.shrink();
      if (role != AppRole.owner || shops.length < 2) return display;
      final label = AppStrings.homeSwitchSalon(selectedName);
      return ListenableBuilder(
        listenable: guard,
        builder: (context, _) {
          final enabled = !guard.busy;
          void choose() => _choose(context, ref);
          return Semantics(
            key: const ValueKey('home-salon-switch'),
            container: true,
            button: true,
            label: label,
            onTap: enabled ? choose : null,
            excludeSemantics: true,
            child: Material(
              color: AppTokens.transparent,
              child: InkWell(
                onTap: enabled ? choose : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.target,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: display),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.expand_more,
                          color: AppTokens.white,
                          size: AppTokens.homeSalonChevronSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    if (role != AppRole.owner || shops.length < 2) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: guard,
      builder: (context, _) {
        if (showLabel) {
          return Tooltip(
            message: AppStrings.switchSalon,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTokens.white,
                minimumSize: const Size(AppTokens.target, AppTokens.target),
              ),
              onPressed: guard.busy ? null : () => _choose(context, ref),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text(AppStrings.switchSalon),
            ),
          );
        }
        return IconButton(
          style: IconButton.styleFrom(
            foregroundColor: AppTokens.white,
            minimumSize: const Size(AppTokens.target, AppTokens.target),
          ),
          tooltip: AppStrings.switchSalon,
          onPressed: guard.busy ? null : () => _choose(context, ref),
          icon: const Icon(Icons.storefront_outlined),
        );
      },
    );
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final scope = (
      ref.read(authControllerProvider).asData?.value.ownership,
      ref.read(selectedShopProvider)?.id,
      ref.read(salonSwitchRevisionProvider),
    );
    bool current() =>
        context.mounted &&
        scope ==
            (
              ref.read(authControllerProvider).asData?.value.ownership,
              ref.read(selectedShopProvider)?.id,
              ref.read(salonSwitchRevisionProvider),
            );
    final guard = ref.read(salonSwitchGuardProvider);
    if (guard.busy) return;
    final shops = ref.read(shopContextProvider).asData?.value?.shops ?? [];
    final id = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.chooseSalon),
        content: SizedBox(
          width: AppTokens.formWidth,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: shops.length,
            itemBuilder: (_, index) => ListTile(
              title: Text(shops[index].name),
              selected: shops[index].id == scope.$2,
              trailing: shops[index].id == scope.$2
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(shops[index].id),
            ),
          ),
        ),
      ),
    );
    if (!context.mounted ||
        !current() ||
        id == null ||
        id == scope.$2 ||
        guard.busy) {
      return;
    }
    var discard = false;
    if (guard.dirty) {
      discard =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text(AppStrings.switchSalon),
              content: const Text(AppStrings.switchUnsaved),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(AppStrings.switchCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(AppStrings.switchDiscard),
                ),
              ],
            ),
          ) ==
          true;
      if (!discard) return;
    }
    if (!current() || guard.busy) return;
    if (ref.read(configProvider).demo) {
      ref
          .read(demoShopSelectionProvider.notifier)
          .select(id, discardConfirmed: discard);
    } else {
      ref
          .read(salonSelectionProvider.notifier)
          .select(id, discardConfirmed: discard);
    }
  }
}

/// Preference failures are nonblocking and contain no account details.
class SalonPreferenceNotice extends ConsumerWidget {
  const SalonPreferenceNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(configProvider).demo ||
        ref.watch(salonSelectionProvider).notice == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        const Text(AppStrings.salonPreferenceFailed),
        TextButton(
          onPressed: () =>
              ref.read(salonSelectionProvider.notifier).retryPreference(),
          child: const Text(AppStrings.retry),
        ),
      ],
    );
  }
}
