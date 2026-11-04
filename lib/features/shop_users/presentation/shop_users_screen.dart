import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../../core/widgets/feature_message.dart';
import '../../menu/presentation/destination_scope_provider.dart';
import '../domain/shop_user.dart';
import 'shop_users_controller.dart';

class ShopUsersScreen extends ConsumerWidget {
  const ShopUsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(shopUsersControllerProvider);
    final scope = ref.watch(destinationScopeProvider('users-shop'));
    final controller = ref.read(shopUsersControllerProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          const AppInnerHeader(title: AppStrings.shopUsers),
          Expanded(
            child: users.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => FeatureMessage(
                message: error is AppFailure
                    ? error.message
                    : AppStrings.unknown,
                onRetry: controller.refresh,
              ),
              data: (view) => view == null || view.scope != scope
                  ? const FeatureMessage(message: AppStrings.noAccessBody)
                  : ShopUsersList(view: view),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopUsersList extends ConsumerWidget {
  const ShopUsersList({super.key, required this.view});
  final ShopUsersView view;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.builder(
    padding: const EdgeInsets.all(AppTokens.homeInset),
    itemCount: view.users.length + 1,
    itemBuilder: (context, index) {
      if (index < view.users.length) {
        return ShopUserCard(user: view.users[index]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (view.users.isEmpty) const Text(AppStrings.shopUsersEmpty),
          if (view.moreFailure case final failure?) Text(failure.message),
          if (view.page.hasNext) ...[
            const SizedBox(height: AppTokens.smallGap),
            if (view.loadingMore)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: () =>
                    ref.read(shopUsersControllerProvider.notifier).loadMore(),
                child: Text(
                  view.moreFailure == null
                      ? AppStrings.loadMore
                      : AppStrings.retry,
                ),
              ),
          ],
        ],
      );
    },
  );
}

class ShopUserCard extends StatelessWidget {
  const ShopUserCard({super.key, required this.user});
  final ShopUser user;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.homeCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (user.displayName != user.email) Text(user.email),
          Text(
            user.phoneNumber?.trim().isNotEmpty == true
                ? user.phoneNumber ?? AppStrings.phoneNotProvided
                : AppStrings.phoneNotProvided,
          ),
          Text(user.role),
          Text(switch (user.active) {
            true => AppStrings.active,
            false => AppStrings.inactive,
            null => AppStrings.userStatusUnknown,
          }),
        ],
      ),
    ),
  );
}
