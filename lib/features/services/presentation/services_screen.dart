import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../../core/widgets/feature_message.dart';
import '../../queue/domain/service_catalogue.dart';
import 'services_controller.dart';

/// Read-only, price-free catalogue for either server-permitted display role.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(servicesCatalogueProvider);
    return Scaffold(
      body: Column(
        children: [
          const AppInnerHeader(title: AppStrings.catalogueServices),
          Expanded(
            child: catalogue.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => FeatureMessage(
                message: error is AppFailure
                    ? error.message
                    : AppStrings.unknown,
                onRetry: () => ref.invalidate(servicesCatalogueProvider),
              ),
              data: (rows) => rows.isEmpty
                  ? const FeatureMessage(message: AppStrings.catalogueEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTokens.homeInset),
                      itemCount: rows.length,
                      itemBuilder: (_, index) =>
                          ServiceCatalogueTile(row: rows[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceCatalogueTile extends StatelessWidget {
  const ServiceCatalogueTile({super.key, required this.row});
  final ServiceCatalogueRow row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(
      start:
          math.min(row.depth, AppTokens.catalogueMaxDepth) *
          AppTokens.catalogueIndent,
      bottom: AppTokens.smallGap,
    ),
    child: Card(
      child: ListTile(
        leading: Icon(
          row.isHeading ? Icons.folder_outlined : Icons.content_cut,
        ),
        title: Semantics(
          header: row.isHeading,
          child: Text(
            row.service.name,
            style: row.isHeading
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        subtitle: !row.service.isBookable
            ? const Text(AppStrings.serviceCategory)
            : null,
      ),
    ),
  );
}
