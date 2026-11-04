import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/status_screen.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../auth/presentation/auth_controller.dart';
import 'menu_controller.dart';

/// Loading/contract/network/forbidden gate, never a default full menu.
class MenuGateScreen extends ConsumerWidget {
  const MenuGateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuControllerProvider);
    final failure = menu.error;
    return StatusScreen(
      header: const AppInnerHeader(title: AppStrings.appName, showBack: false),
      message: failure is AppFailure ? failure.message : AppStrings.menuLoading,
      loading: menu.isLoading,
      onRetry: menu.isLoading
          ? null
          : () => ref.read(menuControllerProvider.notifier).refresh(),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
    );
  }
}
