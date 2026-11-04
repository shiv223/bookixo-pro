import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/offer.dart';
import 'offer_labels.dart';
import 'offers_controller.dart';
import 'offers_widgets.dart';
import 'voucher_card.dart';

class OfferDetailsScreen extends ConsumerWidget {
  const OfferDetailsScreen({super.key, required this.offerId});
  final int offerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(offersControllerProvider).asData?.value;
    final offer = view?.byId[offerId];
    final scope = ref.watch(offersScopeProvider);
    final today = ref.watch(offersTodayProvider);
    final owner =
        ref.watch(authControllerProvider).asData?.value.identity?.role ==
        AppRole.owner;
    final targets = (view?.targetsByOffer[offerId] ?? <OfferTarget>[])
        .where((target) => target.eligible)
        .toList();
    final controller = ref.read(offersControllerProvider.notifier);
    final enabled = view?.canExport(offerId, today) == true;
    return Scaffold(
      body: Column(
        children: [
          AppInnerHeader(
            title: offer?.title ?? AppStrings.offers,
            fallbackRoute: '/web/offers',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTokens.homeInset),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: 1 + targets.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (view == null) const Text(AppStrings.forbidden),
                        ResourceNotice(
                          label: AppStrings.offersResource,
                          resource: view?.offers,
                          onRetry: () =>
                              controller.retry(OffersResource.offers),
                        ),
                        ResourceNotice(
                          label: AppStrings.targetsResource,
                          resource: view?.targets,
                          onRetry: () =>
                              controller.retry(OffersResource.targets),
                        ),
                        ResourceNotice(
                          label: AppStrings.rulesResource,
                          resource: view?.rules,
                          onRetry: () => controller.retry(OffersResource.rules),
                        ),
                        if (offer == null && view?.offers.complete == true)
                          const Text(AppStrings.offerMissing),
                        if (offer != null && !enabled)
                          Text(OfferLabels.note(offer.status(today))),
                        if (offer != null && !offer.knownDiscount)
                          const Text(AppStrings.discountUnavailable),
                        if (view?.schedule(offerId).hasDiagnostics == true)
                          const Text(AppStrings.invalidSchedule),
                        if (targets.isEmpty && view?.targets.complete == true)
                          const Text(AppStrings.noTargets),
                        if (targets.isEmpty &&
                            view?.targets.loading == true) ...[
                          const OfferSkeleton(),
                          const OfferSkeleton(),
                        ],
                        const SizedBox(height: AppTokens.offerPadding),
                      ],
                    );
                  }
                  if (offer == null || scope == null) {
                    return const SizedBox.shrink();
                  }
                  final target = targets[index - 1];
                  return VoucherCardGroup(
                    key: ValueKey(target.id),
                    offer: offer,
                    target: target,
                    shop: scope.shop.name,
                    summary: view?.schedule(offerId),
                    design: (index - 1) % 4,
                    enabled: enabled,
                    dimmed: offer.status(today) != OfferStatus.active,
                    overlap: owner && target.hasAnotherOfferForSameService,
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
