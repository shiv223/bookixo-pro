import 'dart:async';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/queue/data/mock_queue_repository.dart';
import 'package:bookixo_pro/features/queue/domain/queue_item.dart';
import 'package:bookixo_pro/features/queue/presentation/booking_flow_controller.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_selection_controller.dart';
import 'package:bookixo_pro/features/shop_context/presentation/salon_switch_guard.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../shop_context/salon_selection_test.dart' show MemorySalonPreferences;

class GatedQueue extends MockQueueRepository {
  final lookupGate = Completer<CustomerLookup?>();
  final createGate = Completer<QueueItem>();
  final startGate = Completer<QueueItem>();
  int starts = 0;
  @override
  Future<CustomerLookup?> lookupCustomer(String phoneNumber) =>
      lookupGate.future;
  @override
  Future<QueueItem> createWalkIn(NewBookingRequest request) =>
      createGate.future;
  @override
  Future<QueueItem> start(String bookingId) {
    starts++;
    return startGate.future;
  }
}

void main() {
  late ProviderContainer container;
  late GatedQueue queue;
  setUp(() {
    queue = GatedQueue();
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository()..restored = sampleSession(),
        ),
        clockProvider.overrideWithValue(FakeClock()),
        shopRepositoryProvider.overrideWithValue(
          FakeShopRepository()
            ..result = ShopContext(const [Shop(15, 'A'), Shop(16, 'B')], 15),
        ),
        salonPreferenceRepositoryProvider.overrideWithValue(
          MemorySalonPreferences(),
        ),
        queueRepositoryProvider.overrideWithValue(queue),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<BookingFlowController> boot() async {
    await container.read(authControllerProvider.future);
    await container.read(shopContextProvider.future);
    container.read(selectedShopProvider);
    await flush();
    return container.read(bookingFlowControllerProvider.notifier);
  }

  test('production A B A drops inflight lookup/customer state', () async {
    final flow = await boot();
    final lookup = flow.lookupCustomer('9876543210');
    final selection = container.read(salonSelectionProvider.notifier);
    selection.select(16);
    selection.select(15);
    queue.lookupGate.complete(
      const CustomerLookup(
        firstName: 'Old branch',
        lastName: '',
        gender: null,
        dateOfBirth: null,
      ),
    );
    await lookup;
    expect(container.read(bookingFlowControllerProvider).customer, isNull);
    expect(
      container.read(bookingFlowControllerProvider).lookupStatus,
      CustomerLookupStatus.idle,
    );
  });
  test(
    'inflight creation blocks switch; logout prevents automatic claim',
    () async {
      final flow = await boot();
      final create = flow.createWalkIn(
        const NewBookingRequest(
          phoneNumber: '9876543210',
          firstName: 'Sample',
          lastName: '',
        ),
        startImmediately: true,
      );
      expect(container.read(salonSwitchGuardProvider).busy, true);
      expect(container.read(salonSelectionProvider.notifier).select(16), false);
      await container.read(authControllerProvider.notifier).logout();
      queue.createGate.complete(const QueueItem('old', 'Old branch', ''));
      expect(await create, isNull);
      expect(queue.starts, 0);
      expect(container.read(salonSwitchGuardProvider).busy, false);
      expect(
        container.read(bookingFlowControllerProvider).createdBooking,
        isNull,
      );
    },
  );
  test('inflight claim blocks switch and drops result after logout', () async {
    final flow = await boot();
    final claim = flow.startQueueBooking('old');
    expect(container.read(salonSelectionProvider.notifier).select(16), false);
    await container.read(authControllerProvider.notifier).logout();
    queue.startGate.complete(const QueueItem('old', 'Old branch', ''));
    expect(await claim, false);
    expect(queue.starts, 1);
    expect(container.read(salonSwitchGuardProvider).busy, false);
  });
}
