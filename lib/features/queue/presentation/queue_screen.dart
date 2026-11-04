import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_inner_header.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_controller.dart';
import '../domain/queue_item.dart';
import 'booking_flow_controller.dart';
import 'queue_controller.dart';
import 'queue_realtime_controller.dart';
import 'queue_realtime_coordinator.dart';
import '../../shop_context/presentation/salon_chooser.dart';

/// Queue tabs exist only when their exact server menu keys are present.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key, this.requestedTab});

  final String? requestedTab;

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen>
    with WidgetsBindingObserver {
  QueueRealtimeCoordinator? _realtimeCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeCoordinator = ref.read(queueRealtimeCoordinatorProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _realtimeCoordinator?.resume();
      _refreshVisibleQueue();
    } else {
      final coordinator = _realtimeCoordinator;
      if (coordinator != null) unawaited(coordinator.pause());
    }
  }

  @override
  void dispose() {
    final coordinator = _realtimeCoordinator;
    if (coordinator != null) unawaited(coordinator.pause());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshVisibleQueue() {
    final tabs =
        ref.read(menuControllerProvider).asData?.value?.projection.tabs ?? [];
    for (final tab in tabs) {
      ref.invalidate(queueItemsProvider(tab.selector));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    _realtimeCoordinator = ref.watch(queueRealtimeCoordinatorProvider);
    final realtimeStatus = ref.watch(queueRealtimeStatusProvider).asData?.value;
    final tabs =
        ref.watch(menuControllerProvider).asData?.value?.projection.tabs ?? [];
    final route = ref
        .watch(menuControllerProvider)
        .asData
        ?.value
        ?.projection
        .tiles
        .where((tile) => tile.tabs.isNotEmpty)
        .firstOrNull
        ?.route;
    final selected =
        tabs.where((tab) => tab.selector == widget.requestedTab).firstOrNull ??
        tabs.firstOrNull;
    final pending = tabs
        .where((tab) => tab.selector == QueueTabSelector.pending)
        .firstOrNull;
    final inProgress = tabs
        .where((tab) => tab.selector == QueueTabSelector.inProgress)
        .firstOrNull;
    final pendingItems = pending == null
        ? null
        : ref.watch(queueItemsProvider(pending.selector));
    final inProgressItems = inProgress == null
        ? null
        : ref.watch(queueItemsProvider(inProgress.selector));
    final canCreate = tabs.isNotEmpty && ref.watch(canCreateWalkInProvider);
    final identity = ref.watch(
      authControllerProvider.select((auth) => auth.asData?.value.identity),
    );
    final role = identity?.role ?? AppRole.unknown;
    final employee = role == AppRole.employee;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton(
              tooltip: AppStrings.addWalkIn,
              onPressed: () => context.go('/queue/new'),
              backgroundColor: AppTokens.accent,
              foregroundColor: AppTokens.accentInk,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          AppInnerHeader(
            title: AppStrings.operations,
            showBack: !employee,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            trailing: employee
                ? _QueueHeaderActions(
                    onLogout: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  )
                : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  _refreshQueue(ref, pending?.selector, inProgress?.selector),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppTokens.homeInset),
                children: [
                  Text(
                    ref.watch(queueIsMockProvider)
                        ? AppStrings.mockQueue
                        : AppStrings.liveQueue,
                  ),
                  if (realtimeStatus != null)
                    _QueueRealtimeNotice(status: realtimeStatus),
                  const SalonPreferenceNotice(),
                  const SizedBox(height: AppTokens.smallGap),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.queueTodayDate(
                            ref.read(clockProvider).now(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _refreshQueue(
                          ref,
                          pending?.selector,
                          inProgress?.selector,
                        ),
                        child: const Text(AppStrings.refresh),
                      ),
                    ],
                  ),
                  if (tabs.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.smallGap),
                    SegmentedButton<String>(
                      segments: [
                        for (final tab in tabs)
                          ButtonSegment<String>(
                            value: tab.selector,
                            label: Text(
                              AppStrings.queueTabLabel(
                                tab.title,
                                _queueCount(
                                  tab.selector,
                                  pendingItems,
                                  inProgressItems,
                                ),
                              ),
                            ),
                          ),
                      ],
                      selected: {selected?.selector ?? tabs.first.selector},
                      onSelectionChanged: route == null
                          ? null
                          : (selection) => context.go(
                              Uri(
                                path: route,
                                queryParameters: {'tab': selection.single},
                              ).toString(),
                            ),
                    ),
                    const SizedBox(height: AppTokens.gap),
                    if (selected != null) QueueItems(tab: selected.selector),
                  ] else
                    const Text(AppStrings.queueEmpty),
                  const SizedBox(height: AppTokens.homeInset * 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRealtimeNotice extends ConsumerWidget {
  const _QueueRealtimeNotice({required this.status});

  final QueueRealtimeStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (status) {
      QueueRealtimeStatus.unconfigured => AppStrings.queueRealtimeNotConfigured,
      QueueRealtimeStatus.connecting => AppStrings.queueRealtimeConnecting,
      QueueRealtimeStatus.subscribed => AppStrings.queueRealtimeConnected,
      QueueRealtimeStatus.disconnected => AppStrings.queueRealtimeDisconnected,
      QueueRealtimeStatus.unavailable => AppStrings.queueRealtimeUnavailable,
      QueueRealtimeStatus.disabled ||
      QueueRealtimeStatus.demo ||
      QueueRealtimeStatus.paused => null,
    };
    if (message == null) return const SizedBox.shrink();
    final canRetry =
        status == QueueRealtimeStatus.disconnected ||
        status == QueueRealtimeStatus.unavailable;
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.smallGap),
      child: Row(
        children: [
          Icon(
            status == QueueRealtimeStatus.subscribed ? Icons.wifi : Icons.sync,
            size: AppTokens.offerCaption,
            color: status == QueueRealtimeStatus.subscribed
                ? AppTokens.success
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTokens.smallGap),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (canRetry)
            TextButton(
              onPressed: () =>
                  ref.read(queueRealtimeCoordinatorProvider).retry(),
              child: const Text(AppStrings.queueRealtimeRetry),
            ),
        ],
      ),
    );
  }
}

class _QueueHeaderActions extends StatelessWidget {
  const _QueueHeaderActions({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onLogout,
    icon: const Icon(Icons.logout),
    label: const Text(AppStrings.logout),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(AppTokens.target, AppTokens.target),
      foregroundColor: AppTokens.white,
      side: BorderSide(
        color: AppTokens.white.withValues(
          alpha: AppTokens.innerHeaderTranslucency,
        ),
      ),
    ),
  );
}

Future<void> _refreshQueue(
  WidgetRef ref,
  String? pendingSelector,
  String? inProgressSelector,
) async {
  final selectors = [pendingSelector, inProgressSelector].whereType<String>();
  await Future.wait([
    for (final selector in selectors)
      ref
          .refresh(queueItemsProvider(selector).future)
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              if (error is AppFailure) return;
              Error.throwWithStackTrace(error, stackTrace);
            },
          ),
  ]);
}

int? _queueCount(
  String selector,
  AsyncValue<List<QueueItem>>? pending,
  AsyncValue<List<QueueItem>>? inProgress,
) {
  final value = selector == QueueTabSelector.pending ? pending : inProgress;
  return value?.asData?.value.length;
}

class QueueItems extends ConsumerWidget {
  const QueueItems({super.key, required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(queueItemsProvider(tab))
      .when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppTokens.gap),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Column(
          children: [
            Text(error is AppFailure ? error.message : AppStrings.unknown),
            TextButton(
              onPressed: () => ref.invalidate(queueItemsProvider(tab)),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(AppTokens.gap),
                child: Text(AppStrings.queueEmpty),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.smallGap),
                  child: _QueueBookingCard(item: items[index]),
                ),
              ),
      );
}

class _QueueBookingCard extends ConsumerWidget {
  const _QueueBookingCard({required this.item});

  final QueueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingFlowControllerProvider);
    final item = this.item;
    final starting = flow.startingBookingId == item.id;
    final anyStartRunning = flow.startingBookingId != null;
    final errorMessage = flow.failedStartBookingId == item.id
        ? flow.errorMessage
        : null;
    final isPending = item.status == QueueBookingStatus.pending;
    final bookingTimeUtc = item.bookingTimeUtc;
    final status = isPending
        ? AppStrings.pendingBookings
        : item.awaitingPayment
        ? AppStrings.awaitingPayment
        : item.hasServices
        ? AppStrings.readyToPay
        : item.assignedToCurrentUser
        ? AppStrings.withYou
        : _assigneeLabel(item);
    final badgeKind = isPending
        ? _BadgeKind.pending
        : item.awaitingPayment
        ? _BadgeKind.neutral
        : item.hasServices
        ? _BadgeKind.success
        : _BadgeKind.info;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isPending ? null : () => context.push('/queue/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.offerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: AppTokens.dashboardAvatar / 2,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Text(_initials(item.customer)),
                  ),
                  const SizedBox(width: AppTokens.smallGap),
                  Expanded(
                    child: Text(
                      AppStrings.queueCustomer(item.queueNumber, item.customer),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _StatusBadge(label: status, kind: badgeKind),
                ],
              ),
              const SizedBox(height: AppTokens.smallGap),
              Text(
                isPending && bookingTimeUtc != null
                    ? _queueWaitLabel(
                        bookingTimeUtc,
                        ref.read(clockProvider).now(),
                      )
                    : item.service,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (errorMessage case final message?) ...[
                const SizedBox(height: AppTokens.smallGap),
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: AppTokens.smallGap),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: anyStartRunning
                        ? null
                        : () async {
                            final started = await ref
                                .read(bookingFlowControllerProvider.notifier)
                                .startQueueBooking(item.id);
                            if (!context.mounted) return;
                            if (started) {
                              ref.invalidate(
                                queueItemsProvider(QueueTabSelector.pending),
                              );
                              ref.invalidate(
                                queueItemsProvider(QueueTabSelector.inProgress),
                              );
                              context.push('/queue/${item.id}');
                            } else {
                              ref.invalidate(
                                queueItemsProvider(QueueTabSelector.pending),
                              );
                            }
                          },
                    child: starting
                        ? const SizedBox.square(
                            dimension: AppTokens.progressSize,
                            child: CircularProgressIndicator(
                              strokeWidth: AppTokens.progressStroke,
                              color: AppTokens.white,
                            ),
                          )
                        : const Text(AppStrings.startBooking),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _queueWaitLabel(DateTime bookingTimeUtc, DateTime now) {
  final elapsedMinutes = now.toUtc().difference(bookingTimeUtc).inMinutes;
  if (elapsedMinutes < 1) return AppStrings.queueWaitUnderMinute;
  if (elapsedMinutes < 60) return AppStrings.queueWaitMinutes(elapsedMinutes);
  final hours = elapsedMinutes ~/ 60;
  final minutes = elapsedMinutes % 60;
  return AppStrings.queueWaitHours(hours, minutes);
}

String _initials(String customer) {
  final trimmed = customer.trim();
  if (trimmed.isEmpty) return '?';
  final names = trimmed.split(RegExp(r'\s+'));
  if (names.isEmpty || names.first.isEmpty) return '?';
  return names.length == 1
      ? names.first.characters.first.toUpperCase()
      : '${names.first.characters.first}${names.last.characters.first}'
            .toUpperCase();
}

String _assigneeLabel(QueueItem item) {
  final firstName = item.assigneeFirstName;
  return firstName == null
      ? AppStrings.inProgress
      : AppStrings.withStaff(firstName);
}

enum _BadgeKind { pending, info, success, neutral }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.kind});

  final String label;
  final _BadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final background = switch (kind) {
      _BadgeKind.pending => AppTokens.queuePendingBackground,
      _BadgeKind.info => AppTokens.queueInfoBackground,
      _BadgeKind.success => AppTokens.queueReadyBackground,
      _BadgeKind.neutral => Theme.of(context).colorScheme.surface,
    };
    final foreground = switch (kind) {
      _BadgeKind.pending => AppTokens.queuePendingInk,
      _BadgeKind.info => AppTokens.queueInfoInk,
      _BadgeKind.success => AppTokens.queueReadyInk,
      _BadgeKind.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.cardRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.smallGap,
          vertical: AppTokens.smallGap / 2,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
