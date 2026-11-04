import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../shop_context/presentation/demo_shop_switcher.dart';
import 'auth_controller.dart';

/// Visible proactive renewal feedback; demo controls never appear in production.
class SessionTools extends ConsumerWidget {
  const SessionTools({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(authControllerProvider).asData?.value;
    final notice = view?.notice;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notice != null) ...[
          const SizedBox(height: AppTokens.gap),
          Text(notice.message),
          FilledButton(
            onPressed: view?.renewing == true
                ? null
                : () => ref.read(authControllerProvider.notifier).retry(),
            child: const Text(AppStrings.retry),
          ),
        ],
        const DemoShopSwitcher(),
      ],
    );
  }
}
