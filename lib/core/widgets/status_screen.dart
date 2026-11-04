import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/role_policy.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../localization/app_strings.dart';
import '../theme/app_tokens.dart';
import 'app_inner_header.dart';
import 'shop_header_title.dart';

/// Shared accessible gate with explicit retry and logout actions.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.message,
    this.loading = false,
    this.onRetry,
    this.onLogout,
    this.footer,
    this.header,
  });
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  final VoidCallback? onLogout;
  final Widget? footer;
  final AppInnerHeader? header;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: header == null
        ? AppBar(title: const ShopHeaderTitle(title: AppStrings.appName))
        : null,
    body: header == null
        ? _StatusContent(screen: this)
        : Column(
            children: [
              if (header case final AppInnerHeader innerHeader) innerHeader,
              Expanded(child: _StatusContent(screen: this)),
            ],
          ),
  );
}

class _StatusContent extends ConsumerWidget {
  const _StatusContent({required this.screen});
  final StatusScreen screen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (screen.loading) const CircularProgressIndicator(),
          const SizedBox(height: AppTokens.gap),
          Text(screen.message, textAlign: TextAlign.center),
          if (screen.footer case final Widget child) child,
          if (screen.onRetry != null)
            FilledButton(
              onPressed: screen.onRetry,
              child: const Text(AppStrings.retry),
            ),
          if (screen.onLogout != null &&
              ref.watch(authControllerProvider).asData?.value.identity?.role !=
                  AppRole.owner)
            TextButton(
              onPressed: screen.onLogout,
              child: const Text(AppStrings.logout),
            ),
        ],
      ),
    ),
  );
}
