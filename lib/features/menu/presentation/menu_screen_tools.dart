import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/session_tools.dart';
import 'menu_controller.dart';
import '../../shop_context/presentation/salon_chooser.dart';

/// Non-Home refresh controls, retaining the existing employee sign-out only.
class MenuActions extends ConsumerWidget {
  const MenuActions({
    super.key,
    this.onFeatureRefresh,
    this.featureBusy = false,
  });
  final VoidCallback? onFeatureRefresh;
  final bool featureBusy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy =
        ref.watch(menuControllerProvider).asData?.value?.refreshing == true;
    final employee =
        ref.watch(authControllerProvider).asData?.value.identity?.role ==
        AppRole.employee;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppStrings.refresh,
          onPressed: busy || featureBusy
              ? null
              : () {
                  ref.read(menuControllerProvider.notifier).refresh();
                  onFeatureRefresh?.call();
                },
          icon: const Icon(Icons.refresh),
        ),
        if (employee)
          IconButton(
            tooltip: AppStrings.logout,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
      ],
    );
  }
}

/// Stale and persistence failures remain visible alongside current access.
class MenuNotice extends ConsumerWidget {
  const MenuNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(menuControllerProvider).asData?.value;
    final notice = view?.notice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view?.refreshing == true) const LinearProgressIndicator(),
        if (notice != null) ...[
          const SizedBox(height: AppTokens.gap),
          Text(
            view?.stale == true
                ? AppStrings.staleMenu
                : notice is StorageFailure
                ? AppStrings.menuStorage
                : notice.message,
          ),
          if (view?.stale == true) Text(notice.message),
          TextButton(
            onPressed: view?.refreshing == true
                ? null
                : () => ref.read(menuControllerProvider.notifier).refresh(),
            child: const Text(AppStrings.retry),
          ),
        ],
        const SessionTools(),
        const SalonPreferenceNotice(),
      ],
    );
  }
}
