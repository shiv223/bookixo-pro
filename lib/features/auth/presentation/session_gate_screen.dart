import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/status_screen.dart';
import 'auth_controller.dart';

class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final failure = state.error;
    return StatusScreen(
      loading: state.isLoading || state.asData?.value.locked == true,
      message: failure is AppFailure ? failure.message : AppStrings.loading,
      onRetry: state.hasError
          ? () => ref.read(authControllerProvider.notifier).retry()
          : null,
      onLogout: state.hasError
          ? () => ref.read(authControllerProvider.notifier).logout()
          : null,
    );
  }
}
