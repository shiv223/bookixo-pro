import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/dashboard_analytics.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_controller.dart';
import 'dashboard_format.dart';

enum DashboardBlock {
  range,
  hero,
  keyNumbers,
  insight,
  trend,
  paymentModes,
  appointments,
  services,
  staff,
  lowStock,
  more,
}

class DashboardBlockView extends StatelessWidget {
  const DashboardBlockView({
    required this.block,
    required this.view,
    required this.controller,
    super.key,
  });

  final DashboardBlock block;
  final DashboardView view;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (block) {
      DashboardBlock.range => const DashboardRangeControl(),
      DashboardBlock.hero => _hero(context),
      DashboardBlock.keyNumbers => _keyNumbers(context),
      DashboardBlock.insight => _insight(context),
      DashboardBlock.trend => _trend(context),
      DashboardBlock.paymentModes => _payment(context),
      DashboardBlock.appointments => _appointments(context),
      DashboardBlock.services => _services(context),
      DashboardBlock.staff => _staff(context),
      DashboardBlock.lowStock => _lowStock(context),
      DashboardBlock.more => _more(context),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.dashboardBlockGap),
      child: content,
    );
  }

  Widget _hero(BuildContext context) {
    final bookings = view.rows<BookingReportRow>(DashboardResource.bookings);
    final orders = view.rows<ProductOrderRow>(DashboardResource.orders);
    final previousBookings = view.rows<BookingReportRow>(
      DashboardResource.previousBookings,
    );
    final previousOrders = view.rows<ProductOrderRow>(
      DashboardResource.previousOrders,
    );
    final keys = const [DashboardResource.bookings, DashboardResource.orders];
    if (_failed(keys)) return _retryCard(context, keys);
    if (bookings == null || orders == null) {
      return const DashboardSkeleton(height: 150);
    }
    final amount =
        DashboardAnalytics.sumBookings(
          bookings,
          (row) => row.remainingAmountPaid,
        ) +
        DashboardAnalytics.sumOrders(orders);
    final previous = previousBookings == null || previousOrders == null
        ? null
        : DashboardAnalytics.sumBookings(
                previousBookings,
                (row) => row.remainingAmountPaid,
              ) +
              DashboardAnalytics.sumOrders(previousOrders);
    final change = previous == null
        ? null
        : DashboardAnalytics.percentChange(amount, previous);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.dashboardHeroPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.dashboardHeroStart, AppTokens.dashboardHeroEnd],
        ),
        borderRadius: BorderRadius.circular(AppTokens.dashboardHeroRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.dashboardNetRevenue,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTokens.white.withValues(alpha: 0.7),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppTokens.smallGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatInr(amount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTokens.white,
                fontSize: AppTokens.dashboardHeroAmount,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: AppTokens.smallGap),
            ChangePill(change: change),
          ],
          if (_hasFailure(keys)) ...[
            const SizedBox(height: AppTokens.smallGap),
            _failureNotice(keys),
          ],
        ],
      ),
    );
  }

  Widget _keyNumbers(BuildContext context) {
    const required = [DashboardResource.bookings, DashboardResource.orders];
    if (_failed(required)) return _retryCard(context, required);
    final bookings = view.rows<BookingReportRow>(DashboardResource.bookings);
    final orders = view.rows<ProductOrderRow>(DashboardResource.orders);
    if (bookings == null || orders == null) {
      return const DashboardKeySkeleton();
    }
    final previousBookings = view.rows<BookingReportRow>(
      DashboardResource.previousBookings,
    );
    final previousOrders = view.rows<ProductOrderRow>(
      DashboardResource.previousOrders,
    );
    final currentService = DashboardAnalytics.sumBookings(
      bookings,
      (row) => row.finalAmount,
    );
    final currentProduct = DashboardAnalytics.sumOrders(orders);
    final count = DashboardAnalytics.completedBills(bookings);
    final previousService = previousBookings == null
        ? null
        : DashboardAnalytics.sumBookings(
            previousBookings,
            (row) => row.finalAmount,
          );
    final previousProduct = previousOrders == null
        ? null
        : DashboardAnalytics.sumOrders(previousOrders);
    final previousCount = previousBookings == null
        ? null
        : DashboardAnalytics.completedBills(previousBookings);
    return Column(
      children: [
        if (_hasFailure(const [
          DashboardResource.previousBookings,
          DashboardResource.previousOrders,
        ]))
          _failureNotice(const [
            DashboardResource.previousBookings,
            DashboardResource.previousOrders,
          ]),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = AppTokens.smallGap.toDouble();
            final width = (constraints.maxWidth - gap) / 2;
            final values = [
              DashboardKpiData(
                AppStrings.dashboardServiceRevenue,
                currentService,
                previousService,
              ),
              DashboardKpiData(
                AppStrings.dashboardProductRevenue,
                currentProduct,
                previousProduct,
              ),
              DashboardKpiData(
                AppStrings.dashboardAverageBill,
                count == 0 ? 0 : currentService / count,
                previousCount == null || previousCount == 0
                    ? null
                    : previousService! / previousCount,
              ),
              DashboardKpiData(
                AppStrings.dashboardBills,
                count.toDouble(),
                previousCount?.toDouble(),
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final data in values)
                  SizedBox(
                    width: width,
                    child: _KpiCard(data: data),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _insight(BuildContext context) {
    final key = const [DashboardResource.staffServices];
    if (_failed(key)) return _retryCard(context, key);
    final rows = view.rows<AssigneeServiceRow>(DashboardResource.staffServices);
    if (rows == null) return const DashboardSkeleton(height: 72);
    final top = DashboardAnalytics.topServices(rows, limit: 1);
    if (top.isEmpty && !_hasFailure(key)) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_hasFailure(key)) _failureNotice(key),
        if (top.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppTokens.dashboardCardPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTokens.infoDarkBackground
                  : AppTokens.infoBackground,
              borderRadius: BorderRadius.circular(AppTokens.dashboardRadius),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: colors.primary),
                const SizedBox(width: AppTokens.smallGap),
                Expanded(
                  child: Text(
                    AppStrings.dashboardTopService(
                      top.first.label,
                      formatInr(top.first.amount),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTokens.infoDarkInk
                          : AppTokens.darkBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _trend(BuildContext context) {
    final bookings = view.rows<BookingReportRow>(DashboardResource.bookings);
    final orders = view.rows<ProductOrderRow>(DashboardResource.orders);
    if (bookings == null || orders == null) {
      final keys = const [DashboardResource.bookings, DashboardResource.orders];
      return _failed(keys)
          ? _retryCard(context, keys)
          : const DashboardSkeleton(height: 210);
    }
    final buckets = DashboardAnalytics.trend(
      range: view.range,
      window: view.window,
      bookings: bookings,
      orders: orders,
    );
    return DashboardCard(
      title: AppStrings.dashboardTrend,
      child: Column(
        children: [
          if (_hasFailure(const [
            DashboardResource.bookings,
            DashboardResource.orders,
          ]))
            _failureNotice(const [
              DashboardResource.bookings,
              DashboardResource.orders,
            ]),
          buckets.isEmpty
              ? const EmptyBlock(message: AppStrings.dashboardNoSales)
              : RevenueBars(buckets: buckets),
        ],
      ),
    );
  }

  Widget _payment(BuildContext context) {
    final bookings = view.rows<BookingReportRow>(DashboardResource.bookings);
    const keys = [DashboardResource.bookings];
    if (_failed(keys)) return _retryCard(context, keys);
    if (bookings == null) return const DashboardSkeleton(height: 170);
    final grouped = <String, double>{};
    final seen = <int>{};
    for (final row in bookings) {
      if (seen.add(row.bookingId) && row.paymentMode.trim().isNotEmpty) {
        grouped.update(
          row.paymentMode.trim(),
          (amount) => amount + row.remainingAmountPaid,
          ifAbsent: () => row.remainingAmountPaid,
        );
      }
    }
    final modes = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = modes.fold<double>(0, (sum, item) => sum + item.value);
    return DashboardCard(
      title: AppStrings.dashboardPaymentModes,
      child: total == 0
          ? Column(
              children: [
                if (_hasFailure(keys)) _failureNotice(keys),
                const EmptyBlock(message: AppStrings.dashboardNoSales),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasFailure(keys)) _failureNotice(keys),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppTokens.dashboardSplitBarRadius,
                  ),
                  child: SizedBox(
                    height: AppTokens.dashboardBarHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < modes.length; i++)
                          if (modes[i].value > 0)
                            Expanded(
                              flex: math.max(
                                1,
                                (modes[i].value / total * 1000).round(),
                              ),
                              child: ColoredBox(
                                color: _paymentColor(modes[i].key, i),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.gap),
                Wrap(
                  spacing: AppTokens.gap,
                  runSpacing: AppTokens.smallGap,
                  children: [
                    for (var i = 0; i < modes.length; i++)
                      PaymentLegend(
                        label: modes[i].key,
                        amount: modes[i].value,
                        color: _paymentColor(modes[i].key, i),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _appointments(BuildContext context) {
    final statuses = view.rows<BookingStatusRow>(DashboardResource.statuses);
    const keys = [DashboardResource.statuses];
    if (_failed(keys)) return _retryCard(context, keys);
    if (statuses == null) return const DashboardSkeleton(height: 160);
    final counts = DashboardAnalytics.appointmentCounts(statuses).values;
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    if (total == 0) {
      return DashboardCard(
        title: AppStrings.dashboardAppointments,
        child: Column(
          children: [
            if (_hasFailure(keys)) _failureNotice(keys),
            const EmptyBlock(message: AppStrings.dashboardNoSales),
          ],
        ),
      );
    }
    const known = [
      AppStrings.dashboardCompleted,
      AppStrings.dashboardPending,
      AppStrings.dashboardInProgress,
      AppStrings.dashboardConfirmed,
      AppStrings.dashboardCancelled,
      AppStrings.dashboardNoShow,
    ];
    final labels = [
      ...known.where(counts.containsKey),
      ...counts.keys.where((key) => !known.contains(key)),
    ];
    return DashboardCard(
      title: AppStrings.dashboardAppointments,
      child: Column(
        children: [
          if (_hasFailure(keys)) _failureNotice(keys),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              AppTokens.dashboardSplitBarRadius,
            ),
            child: SizedBox(
              height: AppTokens.dashboardBarHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final label in labels)
                    if ((counts[label] ?? 0) > 0)
                      Expanded(
                        flex: counts[label]!,
                        child: ColoredBox(color: _statusColor(label)),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTokens.gap),
          Wrap(
            spacing: AppTokens.gap,
            runSpacing: AppTokens.smallGap,
            children: [
              for (final label in labels)
                StatusCount(label: label, count: counts[label] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _services(BuildContext context) {
    final key = const [DashboardResource.staffServices];
    if (_failed(key)) return _retryCard(context, key);
    final rows = view.rows<AssigneeServiceRow>(DashboardResource.staffServices);
    if (rows == null) return const DashboardSkeleton(height: 190);
    final top = DashboardAnalytics.topServices(rows, limit: 5);
    return DashboardCard(
      title: AppStrings.dashboardTopServices,
      trailing: top.isEmpty
          ? null
          : SeeAllButton(onTap: () => context.push('/dashboard/services')),
      child: top.isEmpty && !_hasFailure(key)
          ? const EmptyBlock(message: AppStrings.dashboardNoServices)
          : Column(
              children: [
                if (_hasFailure(key)) _failureNotice(key),
                if (top.isEmpty)
                  const EmptyBlock(message: AppStrings.dashboardNoServices),
                for (var index = 0; index < top.length; index++) ...[
                  ServiceRankRow(
                    rank: index + 1,
                    value: top[index],
                    max: top.first.amount,
                  ),
                  if (index + 1 < top.length)
                    const SizedBox(height: AppTokens.gap),
                ],
              ],
            ),
    );
  }

  Widget _staff(BuildContext context) {
    final key = const [DashboardResource.staffServices];
    if (_failed(key)) return _retryCard(context, key);
    final rows = view.rows<AssigneeServiceRow>(DashboardResource.staffServices);
    if (rows == null) return const DashboardSkeleton(height: 190);
    final staff = DashboardAnalytics.topStaff(rows, limit: 4);
    return DashboardCard(
      title: AppStrings.dashboardTopStaff,
      trailing: staff.isEmpty
          ? null
          : SeeAllButton(onTap: () => context.push('/dashboard/staff')),
      child: staff.isEmpty && !_hasFailure(key)
          ? const EmptyBlock(message: AppStrings.dashboardNoStaff)
          : Column(
              children: [
                if (_hasFailure(key)) _failureNotice(key),
                if (staff.isEmpty)
                  const EmptyBlock(message: AppStrings.dashboardNoStaff),
                for (var index = 0; index < staff.length; index++) ...[
                  StaffRankRow(
                    staff: staff[index],
                    onTap: () => context.push('/dashboard/staff/$index'),
                  ),
                  if (index + 1 < staff.length)
                    const Divider(height: AppTokens.gap),
                ],
              ],
            ),
    );
  }

  Widget _lowStock(BuildContext context) {
    const keys = [DashboardResource.inventory];
    if (_failed(keys)) return _retryCard(context, keys);
    final products = view.rows<InventoryProduct>(DashboardResource.inventory);
    if (products == null) return const DashboardSkeleton(height: 88);
    final low = products.where((product) => product.lowStock).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.dashboardRadius),
      onTap: low.isEmpty ? null : () => context.push('/dashboard/low-stock'),
      child: Column(
        children: [
          if (_hasFailure(keys)) _failureNotice(keys),
          DashboardCard(
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTokens.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${low.length} ${AppStrings.dashboardLowStock}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.smallGap),
                      Text(
                        low.isEmpty
                            ? AppStrings.dashboardNoLowStock
                            : '${low.take(3).map((product) => product.name).join(', ')} · ${AppStrings.dashboardCurrentStock}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (low.isNotEmpty) const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _more(BuildContext context) {
    final showCredits = view.features.contains('shop-credits-packages');
    final showMembership = view.features.contains('shop-memberships');
    if (!showCredits && !showMembership) return const SizedBox.shrink();
    final wallet = view.rows<WalletPurchaseRow>(
      DashboardResource.walletPurchases,
    );
    final membership = view.rows<MembershipSaleRow>(
      DashboardResource.membershipSales,
    );
    final bookingRows = view.rows<BookingReportRow>(DashboardResource.bookings);
    final keys = [
      if (showCredits) DashboardResource.walletPurchases,
      if (showMembership) DashboardResource.membershipSales,
    ];
    if (_failed(keys)) return _retryCard(context, keys);
    if ((showCredits && wallet == null) ||
        (showMembership && membership == null)) {
      return const DashboardSkeleton(height: 108);
    }
    double amountFor(String kind) =>
        wallet
            ?.where((row) => row.walletType == kind)
            .fold<double>(0, (sum, row) => sum + row.amount) ??
        0;
    final cards = <(String, double?)>[
      if (showCredits)
        (
          AppStrings.dashboardCreditsUsed,
          bookingRows == null
              ? null
              : DashboardAnalytics.sumBookings(
                  bookingRows,
                  (row) => row.walletCreditUsed,
                ),
        ),
      if (showCredits) (AppStrings.dashboardPackagesSold, amountFor('PACKAGE')),
      if (showCredits) (AppStrings.dashboardCreditsSold, amountFor('CREDIT')),
      if (showMembership)
        (
          AppStrings.dashboardMembershipsSold,
          membership?.fold<double>(0, (sum, row) => sum + row.amount) ?? 0,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasFailure(keys)) _failureNotice(keys),
        if (showCredits &&
            view.resource(DashboardResource.bookings).failure != null)
          _failureNotice(const [DashboardResource.bookings]),
        Text(
          AppStrings.moreDashboard,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppTokens.smallGap),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppTokens.smallGap),
            itemBuilder: (context, index) {
              final amount = cards[index].$2;
              return SizedBox(
                width: AppTokens.dashboardMoreWidth,
                child: DashboardCard(
                  title: cards[index].$1,
                  child: amount == null
                      ? view.resource(DashboardResource.bookings).failure !=
                                null
                            ? RetryMessage(
                                message: AppStrings.dashboardUnavailable,
                                onRetry: () => controller.retry(
                                  DashboardResource.bookings,
                                ),
                              )
                            : const DashboardSkeleton(
                                height: AppTokens.dashboardMoreAmountHeight,
                              )
                      : FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatInr(amount, compact: true),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _failed(List<DashboardResource> resources) => resources.any(
    (key) =>
        view.resource(key).failure != null && view.resource(key).value == null,
  );

  bool _hasFailure(List<DashboardResource> resources) =>
      resources.any((key) => view.resource(key).failure != null);

  Widget _failureNotice(List<DashboardResource> resources) => RetryMessage(
    message: AppStrings.dashboardUnavailable,
    onRetry: () async {
      await Future.wait([
        for (final resource in resources) controller.retry(resource),
      ]);
    },
  );

  Widget _retryCard(BuildContext context, List<DashboardResource> resources) =>
      DashboardCard(
        child: RetryMessage(
          message: AppStrings.dashboardUnavailable,
          onRetry: () async {
            await Future.wait([
              for (final resource in resources) controller.retry(resource),
            ]);
          },
        ),
      );
}

class DashboardRangeControl extends ConsumerWidget {
  const DashboardRangeControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(dashboardRangeProvider);
    final labels = {
      DashboardRange.today: AppStrings.dashboardToday,
      DashboardRange.sevenDays: AppStrings.dashboardSevenDays,
      DashboardRange.thirtyDays: AppStrings.dashboardThirtyDays,
    };
    return SegmentedButton<DashboardRange>(
      segments: [
        for (final range in DashboardRange.values)
          ButtonSegment(value: range, label: Text(labels[range]!)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          ref.read(dashboardRangeProvider.notifier).select(selection.first);
        }
      },
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, AppTokens.target)),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    required this.child,
    this.title,
    this.trailing,
    super.key,
  });
  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final titleWidgets = title == null
        ? const <Widget>[]
        : <Widget>[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: AppTokens.gap),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.dashboardCardPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTokens.darkBorder
              : AppTokens.border,
        ),
        borderRadius: BorderRadius.circular(AppTokens.dashboardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...titleWidgets, child],
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({required this.height, super.key});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppTokens.darkCard
          : AppTokens.border,
      borderRadius: BorderRadius.circular(AppTokens.dashboardRadius),
    ),
  );
}

class DashboardKeySkeleton extends StatelessWidget {
  const DashboardKeySkeleton({super.key});
  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: AppTokens.smallGap,
    runSpacing: AppTokens.smallGap,
    children: [
      DashboardSkeleton(height: 94),
      DashboardSkeleton(height: 94),
      DashboardSkeleton(height: 94),
      DashboardSkeleton(height: 94),
    ],
  );
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppTokens.smallGap),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );
}

class RetryMessage extends StatelessWidget {
  const RetryMessage({required this.message, required this.onRetry, super.key});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(message)),
      TextButton(
        onPressed: onRetry,
        child: const Text(AppStrings.dashboardTryAgain),
      ),
    ],
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final DashboardKpiData data;
  @override
  Widget build(BuildContext context) {
    final percent = data.previous == null
        ? null
        : DashboardAnalytics.percentChange(data.amount, data.previous!);
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTokens.smallGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.label == AppStrings.dashboardBills
                  ? data.amount.round().toString()
                  : formatInr(data.amount, compact: true),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: AppTokens.dashboardValueSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (percent != null) ...[
            const SizedBox(height: AppTokens.smallGap),
            ChangeText(change: percent),
          ],
        ],
      ),
    );
  }
}

class DashboardKpiData {
  const DashboardKpiData(this.label, this.amount, this.previous);
  final String label;
  final double amount;
  final double? previous;
}

class ChangePill extends StatelessWidget {
  const ChangePill({required this.change, super.key});
  final int change;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: (change >= 0 ? AppTokens.success : AppTokens.dashboardNegative)
          .withValues(alpha: AppTokens.dashboardChangeOpacity),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.dashboardChangePaddingX,
        vertical: AppTokens.dashboardChangePaddingY,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: AppTokens.dashboardErrorIcon,
            color: change >= 0
                ? AppTokens.success
                : AppTokens.dashboardNegative,
          ),
          const SizedBox(width: 4),
          Text(
            '$change% ${AppStrings.dashboardPreviousPeriod}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: change >= 0
                  ? AppTokens.success
                  : AppTokens.dashboardNegative,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class ChangeText extends StatelessWidget {
  const ChangeText({required this.change, super.key});
  final int change;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
        color: change >= 0 ? AppTokens.success : AppTokens.dashboardNegative,
        size: AppTokens.dashboardErrorIcon,
      ),
      Text(
        '$change%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: change >= 0 ? AppTokens.success : AppTokens.dashboardNegative,
        ),
      ),
    ],
  );
}

class RevenueBars extends StatelessWidget {
  const RevenueBars({required this.buckets, super.key});
  final List<TrendBucket> buckets;
  @override
  Widget build(BuildContext context) {
    final max = buckets.map((item) => item.amount).reduce(math.max);
    return SizedBox(
      height: 142,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < buckets.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (buckets[i].amount / max).clamp(
                            0.08,
                            1,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTokens.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.smallGap),
                    Text(
                      buckets[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PaymentLegend extends StatelessWidget {
  const PaymentLegend({
    required this.label,
    required this.amount,
    required this.color,
    super.key,
  });
  final String label;
  final double amount;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: AppTokens.dashboardLegendDot,
        backgroundColor: color,
      ),
      const SizedBox(width: AppTokens.dashboardClientGap),
      Text(
        '$label ${formatInr(amount, compact: true)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class StatusCount extends StatelessWidget {
  const StatusCount({required this.label, required this.count, super.key});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label: $count', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class ServiceRankRow extends StatelessWidget {
  const ServiceRankRow({
    required this.rank,
    required this.value,
    required this.max,
    super.key,
  });
  final int rank;
  final RankedValue value;
  final double max;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('$rank.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: AppTokens.smallGap),
          Expanded(
            child: Text(
              value.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(formatInr(value.amount, compact: true)),
        ],
      ),
      const SizedBox(height: AppTokens.dashboardRankGap),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.controlRadius / 3),
        child: LinearProgressIndicator(
          value: max <= 0 ? 0 : (value.amount / max).clamp(0, 1),
          minHeight: AppTokens.dashboardTrackHeight,
          color: AppTokens.accent,
          backgroundColor: AppTokens.border,
        ),
      ),
    ],
  );
}

class StaffRankRow extends StatelessWidget {
  const StaffRankRow({required this.staff, required this.onTap, super.key});
  final StaffSummary staff;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final initials = staff.name.trim().isEmpty
        ? 'S'
        : staff.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.dashboardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTokens.dashboardTapPadding,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppTokens.dashboardAvatar / 2,
                backgroundColor: AppTokens.infoBackground,
                child: Text(
                  initials,
                  style: const TextStyle(color: AppTokens.darkBlue),
                ),
              ),
              const SizedBox(width: AppTokens.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${staff.clients} ${AppStrings.dashboardClients}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.smallGap),
              Text(formatInr(staff.revenue, compact: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class SeeAllButton extends StatelessWidget {
  const SeeAllButton({required this.onTap, super.key});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    child: const Text(AppStrings.dashboardSeeAll),
  );
}

Color _statusColor(String label) => switch (label) {
  AppStrings.dashboardCompleted => AppTokens.dashboardCompleted,
  AppStrings.dashboardPending => AppTokens.dashboardPending,
  AppStrings.dashboardInProgress => AppTokens.primary,
  AppStrings.dashboardConfirmed => AppTokens.dashboardOther,
  AppStrings.dashboardCancelled ||
  AppStrings.dashboardNoShow => AppTokens.dashboardCancelled,
  _ => AppTokens.dashboardOther,
};

Color _paymentColor(String mode, int index) => switch (mode.toUpperCase()) {
  'CASH' => AppTokens.dashboardCash,
  'UPI' => AppTokens.primary,
  'CARD' => AppTokens.dashboardCard,
  _ =>
    AppTokens.dashboardPaymentFallbacks[index %
        AppTokens.dashboardPaymentFallbacks.length],
};
