import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/status_screen.dart';
import 'auth_controller.dart';

class UnsupportedRoleScreen extends ConsumerWidget {
  const UnsupportedRoleScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => StatusScreen(
    message: '${AppStrings.unsupported}\n${AppStrings.contactAdmin}',
    onLogout: () => ref.read(authControllerProvider.notifier).logout(),
  );
}
