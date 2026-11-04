import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../domain/offer.dart';
import 'offers_controller.dart';
import 'offers_widgets.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(offersControllerProvider);
    final view = result.asData?.value;
    final filter = ref.watch(offerFilterProvider);
    final offers = view?.visible(filter) ?? <Offer>[];
    final active = view?.visible(OfferFilter.active).length ?? 0;
    final controller = ref.read(offersControllerProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          AppInnerHeader(
            title: AppStrings.offers,
            trailing: AppInnerHeaderBadge(
              label: view?.rules.complete == true
                  ? AppStrings.offersWithActiveRules(active)
                  : AppStrings.ruleStatusUnavailable,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTokens.homeInset),
                itemCount:
                    5 +
                    (view?.offers.page == -1 && view?.offers.loading == true
                        ? 4
                        : offers.length),
                itemBuilder: (context, index) {
                  if (index == 0) return const OffersWebNotice();
                  if (index == 1) return OfferFilters(view: view);
                  if (index == 2) {
                    return ResourceNotice(
                      label: AppStrings.offersResource,
                      resource: view?.offers,
                      onRetry: () => controller.retry(OffersResource.offers),
                    );
                  }
                  if (index == 3) {
                    return ResourceNotice(
                      label: AppStrings.rulesResource,
                      resource: view?.rules,
                      onRetry: () => controller.retry(OffersResource.rules),
                    );
                  }
                  if (index == 4) {
                    if (view == null) {
                      final error = result.error;
                      return Text(
                        error is AppFailure
                            ? error.message
                            : AppStrings.forbidden,
                      );
                    }
                    if (view.offers.items.isEmpty && view.offers.complete) {
                      return const Text(AppStrings.offersEmpty);
                    }
                    if (offers.isEmpty && view.offers.items.isNotEmpty) {
                      return const Text(AppStrings.noFilteredOffers);
                    }
                    return const SizedBox.shrink();
                  }
                  if (view?.offers.page == -1 && view?.offers.loading == true) {
                    return const OfferSkeleton();
                  }
                  final offer = offers[index - 5];
                  return OfferTicket(
                    key: ValueKey(offer.id),
                    offer: offer,
                    status:
                        view?.listStatus(offer.id) ??
                        OfferListStatus.unavailable,
                    summary: view?.schedule(offer.id),
                    schedulesComplete: view?.rules.complete == true,
                    onTap: () => context.push('/web/offers/${offer.id}'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OfferFilters extends ConsumerWidget {
  const OfferFilters({super.key, required this.view});
  final OffersView? view;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(offerFilterProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.offerPadding),
      child: Wrap(
        spacing: AppTokens.smallGap,
        runSpacing: AppTokens.smallGap,
        children: [
          for (final filter in OfferFilter.values)
            ChoiceChip(
              label: Text(
                filter != OfferFilter.all && view?.rules.complete != true
                    ? AppStrings.filterUnavailable(
                        filter == OfferFilter.active
                            ? AppStrings.active
                            : AppStrings.inactive,
                      )
                    : AppStrings.filterCount(switch (filter) {
                        OfferFilter.all => AppStrings.allOffers,
                        OfferFilter.active => AppStrings.active,
                        OfferFilter.inactive => AppStrings.inactive,
                      }, view?.visible(filter).length ?? 0),
              ),
              selected: selected == filter,
              onSelected: (_) =>
                  ref.read(offerFilterProvider.notifier).select(filter),
            ),
        ],
      ),
    );
  }
}
