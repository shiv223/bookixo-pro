import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/menu_projection.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../data/socket_io_queue_realtime_repository.dart';
import '../domain/queue_realtime_repository.dart';
import 'queue_controller.dart';
import 'queue_realtime_coordinator.dart';

final queueRealtimeRepositoryProvider = Provider<QueueRealtimeRepository>(
  (ref) => SocketIoQueueRealtimeRepository(ref.watch(appLoggerProvider)),
);

final queueRealtimeSchedulerProvider = Provider<QueueRealtimeScheduler>(
  (ref) => const SystemQueueRealtimeScheduler(),
);

/// One connection is owned by the active queue scope, never by a widget.
final queueRealtimeCoordinatorProvider =
    Provider.autoDispose<QueueRealtimeCoordinator>((ref) {
      final config = ref.watch(configProvider);
      final revision = ref.watch(scopeRevisionProvider);
      final scope = ref.watch(menuScopeProvider);
      final shopId = ref.watch(selectedShopProvider.select((shop) => shop?.id));
      final permissionKeys = ref.watch(
        menuControllerProvider.select(
          (menu) => menu.asData?.value?.snapshot.keys,
        ),
      );
      final ownership = ref.watch(
        authControllerProvider.select((auth) => auth.asData?.value.ownership),
      );
      final validatedShopId = scope?.shopId == shopId ? shopId : null;
      final tabs = scope == null || permissionKeys == null
          ? const <String>[]
          : MenuProjection(permissionKeys).tabs
                .map((tab) => tab.selector)
                .toList(growable: false);
      final repository = config.demo || config.socketBaseUrl == null
          ? null
          : ref.watch(queueRealtimeRepositoryProvider);
      final logger = ref.watch(appLoggerProvider);

      bool isCurrent() {
        if (scope == null ||
            permissionKeys == null ||
            validatedShopId == null ||
            !ref.mounted ||
            ref.read(scopeRevisionProvider) != revision ||
            ref.read(menuScopeProvider) != scope ||
            ref.read(selectedShopProvider)?.id != shopId ||
            ref.read(authControllerProvider).asData?.value.ownership !=
                ownership) {
          return false;
        }
        final currentKeys = ref
            .read(menuControllerProvider)
            .asData
            ?.value
            ?.snapshot
            .keys;
        return currentKeys != null && setEquals(currentKeys, permissionKeys);
      }

      Future<void> refreshQueue(List<String> permittedTabs) async {
        await Future.wait([
          for (final tab in permittedTabs)
            ref
                .refresh(queueItemsProvider(tab).future)
                .then<void>(
                  (_) {},
                  onError: (Object error, StackTrace stackTrace) {
                    if (error is AppFailure) return;
                    logger.queueRealtimeFailure(stackTrace);
                  },
                ),
        ]);
      }

      final coordinator = QueueRealtimeCoordinator(
        shopId: validatedShopId,
        permittedTabs: tabs,
        demo: config.demo,
        socketBaseUrl: config.socketBaseUrl,
        repository: repository,
        isCurrentScope: isCurrent,
        refreshQueue: refreshQueue,
        appLogger: logger,
        timerScheduler: ref.watch(queueRealtimeSchedulerProvider),
      );
      coordinator.start();
      ref.onDispose(() => unawaited(coordinator.dispose()));
      return coordinator;
    });

final queueRealtimeStatusProvider =
    StreamProvider.autoDispose<QueueRealtimeStatus>((ref) async* {
      final coordinator = ref.watch(queueRealtimeCoordinatorProvider);
      yield* coordinator.statusChanges;
    });
