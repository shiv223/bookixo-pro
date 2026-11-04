import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import 'dashboard_controller.dart';
import '../domain/dashboard_models.dart';
import 'dashboard_widgets.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final Set<(DashboardBlock, DashboardScope, DashboardRange)> _scheduledLoads =
      {};

  @override
  Widget build(BuildContext context) {
    final asyncView = ref.watch(dashboardControllerProvider);
    final view = asyncView.asData?.value;
    final controller = ref.read(dashboardControllerProvider.notifier);
    final theme = Theme.of(context);
    if (view == null) {
      final message = asyncView.hasError
          ? AppStrings.dashboardUnavailable
          : asyncView.hasValue
          ? AppStrings.noAccessBody
          : null;
      return Scaffold(
        body: Center(
          child: message == null
              ? const DashboardKeySkeleton()
              : Text(message, style: theme.textTheme.bodyMedium),
        ),
      );
    }
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          const AppInnerHeader(title: AppStrings.dashboard),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > AppTokens.homeWidth
                        ? (constraints.maxWidth - AppTokens.homeWidth) / 2
                        : AppTokens.dashboardInset,
                    vertical: AppTokens.dashboardBlockGap,
                  ),
                  itemCount: DashboardBlock.values.length,
                  itemBuilder: (context, index) {
                    final block = DashboardBlock.values[index];
                    _loadVisibleResource(block, view, controller);
                    return DashboardBlockView(
                      key: ValueKey(block),
                      block: block,
                      view: view,
                      controller: controller,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadVisibleResource(
    DashboardBlock block,
    DashboardView view,
    DashboardController controller,
  ) {
    if (!_scheduledLoads.add((block, view.scope, view.range))) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startVisibleResourceLoad(block, controller);
    });
  }

  void _startVisibleResourceLoad(
    DashboardBlock block,
    DashboardController controller,
  ) {
    if (block == DashboardBlock.appointments) {
      controller.load(DashboardResource.statuses);
    } else if (block == DashboardBlock.lowStock) {
      controller.load(DashboardResource.inventory);
    } else if (block == DashboardBlock.more) {
      final access = ref.read(dashboardAccessProvider);
      if (access?.features.contains('shop-credits-packages') == true) {
        controller.load(DashboardResource.walletPurchases);
      }
      if (access?.features.contains('shop-memberships') == true) {
        controller.load(DashboardResource.membershipSales);
      }
    }
  }
}
