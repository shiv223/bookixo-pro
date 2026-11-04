import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';

import 'menu_controller.dart';
import 'menu_screen_tools.dart';

/// Genuine successful empty projection with manual recovery.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        AppInnerHeader(
          title: AppStrings.noAccess,
          showBack: context.canPop(),
          trailing: const MenuActions(),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(menuControllerProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppTokens.padding),
              children: const [Text(AppStrings.noAccessBody), MenuNotice()],
            ),
          ),
        ),
      ],
    ),
  );
}
