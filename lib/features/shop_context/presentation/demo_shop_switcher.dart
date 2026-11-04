import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../auth/presentation/auth_dependencies.dart';

/// This does not select a backend shop or imply server authorization.
class DemoShopSwitcher extends ConsumerWidget {
  const DemoShopSwitcher({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(configProvider).demo) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const Text(AppStrings.demo)],
    );
  }
}
