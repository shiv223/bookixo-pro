import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../domain/dashboard_analytics.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'dashboard_format.dart';
import 'dashboard_widgets.dart';

class DashboardServicesScreen extends ConsumerWidget {
  const DashboardServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncView = ref.watch(dashboardControllerProvider);
    final view = asyncView.asData?.value;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final rows = view?.rows<AssigneeServiceRow>(
      DashboardResource.staffServices,
    );
    return _DashboardListFrame(
      title: AppStrings.dashboardServiceList,
      onRefresh: controller.refresh,
      child: rows == null
          ? _ResourceState(
              state: view?.resource(DashboardResource.staffServices),
              onRetry: () => controller.retry(DashboardResource.staffServices),
            )
          : Builder(
              builder: (context) {
                final values = DashboardAnalytics.topServices(
                  rows,
                  limit: rows.length + 1,
                );
                if (values.isEmpty) {
                  return const EmptyBlock(
                    message: AppStrings.dashboardNoServices,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppTokens.dashboardInset),
                  itemCount: values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTokens.smallGap),
                  itemBuilder: (context, index) => DashboardCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            values[index].label,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(formatInr(values[index].amount)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DashboardStaffScreen extends ConsumerWidget {
  const DashboardStaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncView = ref.watch(dashboardControllerProvider);
    final view = asyncView.asData?.value;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final rows = view?.rows<AssigneeServiceRow>(
      DashboardResource.staffServices,
    );
    return _DashboardListFrame(
      title: AppStrings.dashboardStaffList,
      onRefresh: controller.refresh,
      child: rows == null
          ? _ResourceState(
              state: view?.resource(DashboardResource.staffServices),
              onRetry: () => controller.retry(DashboardResource.staffServices),
            )
          : Builder(
              builder: (context) {
                final staff = DashboardAnalytics.topStaff(
                  rows,
                  limit: rows.length + 1,
                );
                if (staff.isEmpty) {
                  return const EmptyBlock(message: AppStrings.dashboardNoStaff);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppTokens.dashboardInset),
                  itemCount: staff.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTokens.smallGap),
                  itemBuilder: (context, index) => DashboardCard(
                    child: StaffRankRow(
                      staff: staff[index],
                      onTap: () => context.push('/dashboard/staff/$index'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class DashboardStaffDetailScreen extends ConsumerWidget {
  const DashboardStaffDetailScreen({required this.staffIndex, super.key});

  final int staffIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(dashboardControllerProvider).asData?.value;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final rows = view?.rows<AssigneeServiceRow>(
      DashboardResource.staffServices,
    );
    final staff = rows == null
        ? const <StaffSummary>[]
        : DashboardAnalytics.topStaff(rows, limit: rows.length + 1);
    final item = staffIndex >= 0 && staffIndex < staff.length
        ? staff[staffIndex]
        : null;
    return _DashboardListFrame(
      title: AppStrings.dashboardStaffDetail,
      onRefresh: controller.refresh,
      child: rows == null
          ? _ResourceState(
              state: view?.resource(DashboardResource.staffServices),
              onRetry: () => controller.retry(DashboardResource.staffServices),
            )
          : item == null
          ? const EmptyBlock(message: AppStrings.dashboardNoStaff)
          : _StaffDetailContent(staff: item),
    );
  }
}

class _StaffDetailContent extends StatelessWidget {
  const _StaffDetailContent({required this.staff});
  final StaffSummary staff;

  @override
  Widget build(BuildContext context) {
    final average = staff.clients == 0 ? 0 : staff.revenue / staff.clients;
    return ListView(
      padding: const EdgeInsets.all(AppTokens.dashboardInset),
      children: [
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(staff.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTokens.gap),
              _DetailMetric(
                label: AppStrings.dashboardRevenue,
                value: formatInr(staff.revenue),
              ),
              _DetailMetric(
                label: AppStrings.dashboardClientsLabel,
                value: staff.clients.toString(),
              ),
              _DetailMetric(
                label: AppStrings.dashboardAverageBillLabel,
                value: formatInr(average),
              ),
              const _DetailMetric(
                label: AppStrings.dashboardRating,
                value: AppStrings.dashboardRatingUnavailable,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.smallGap),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class DashboardLowStockScreen extends ConsumerWidget {
  const DashboardLowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(dashboardControllerProvider).asData?.value;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final products = view?.rows<InventoryProduct>(DashboardResource.inventory);
    final low = products?.where((product) => product.lowStock).toList();
    return _DashboardListFrame(
      title: AppStrings.dashboardLowStockProducts,
      onRefresh: controller.refresh,
      child: products == null
          ? _ResourceState(
              state: view?.resource(DashboardResource.inventory),
              onRetry: () => controller.retry(DashboardResource.inventory),
            )
          : low!.isEmpty
          ? const EmptyBlock(message: AppStrings.dashboardNoLowStock)
          : ListView.separated(
              padding: const EdgeInsets.all(AppTokens.dashboardInset),
              itemCount: low.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTokens.smallGap),
              itemBuilder: (context, index) {
                final product = low[index];
                return DashboardCard(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: AppTokens.gap),
                      Expanded(child: Text(product.name)),
                      Text(
                        '${AppStrings.dashboardCurrentStock}: ${product.currentStock}',
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _DashboardListFrame extends StatelessWidget {
  const _DashboardListFrame({
    required this.title,
    required this.onRefresh,
    required this.child,
  });
  final String title;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const AppInnerHeader(title: AppStrings.dashboard),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.dashboardInset,
            vertical: AppTokens.smallGap,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const DashboardRangeControl(),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: child is ListView
                ? child
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppTokens.dashboardInset),
                    children: [child],
                  ),
          ),
        ),
      ],
    ),
  );
}

class _ResourceState extends StatelessWidget {
  const _ResourceState({required this.state, required this.onRetry});
  final DashboardResourceState<Object>? state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state?.failure != null) {
      return DashboardCard(
        child: RetryMessage(
          message: AppStrings.dashboardUnavailable,
          onRetry: onRetry,
        ),
      );
    }
    if (state?.loading == true || state?.value == null) {
      return const DashboardSkeleton(height: 120);
    }
    return const EmptyBlock(message: AppStrings.dashboardNoServices);
  }
}
