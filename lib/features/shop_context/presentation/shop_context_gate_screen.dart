import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/status_screen.dart';
import '../../auth/presentation/auth_controller.dart';
import 'shop_context_controller.dart';
import 'salon_selection_controller.dart';

class ShopContextGateScreen extends ConsumerWidget {
  const ShopContextGateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shopContextProvider);
    final restoring = ref.watch(salonSelectionProvider).restoring;
    final error = state.error;
    return StatusScreen(
      loading: state.isLoading || restoring,
      message: state.isLoading || restoring
          ? AppStrings.shopLoading
          : error is AppFailure
          ? error.message
          : state.hasError
          ? AppStrings.unknown
          : AppStrings.noShop,
      onRetry: state.isLoading || restoring
          ? null
          : () => ref.invalidate(shopContextProvider),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
    );
  }
}
