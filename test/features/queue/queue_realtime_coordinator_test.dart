import 'dart:async';

import 'package:bookixo_pro/core/logging/app_logger.dart';
import 'package:bookixo_pro/features/queue/domain/queue_realtime_repository.dart';
import 'package:bookixo_pro/features/queue/presentation/queue_realtime_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConnection implements QueueRealtimeConnection {
  final StreamController<QueueRealtimeSignal> controller =
      StreamController<QueueRealtimeSignal>.broadcast(sync: true);
  final List<int> subscribedShops = [];
  final List<int> unsubscribedShops = [];
  Completer<bool>? nextSubscribeAck;
  bool subscribeResult = true;
  bool throwOnSubscribe = false;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<QueueRealtimeSignal> get signals => controller.stream;

  @override
  void connect() => connectCalls++;

  @override
  Future<bool> subscribe(int shopId) {
    subscribedShops.add(shopId);
    if (throwOnSubscribe) {
      throw StateError('sensitive customer payload and token');
    }
    final ack = nextSubscribeAck;
    nextSubscribeAck = null;
    return ack?.future ?? Future.value(subscribeResult);
  }

  @override
  Future<bool> unsubscribe(int shopId) {
    unsubscribedShops.add(shopId);
    return Future.value(true);
  }

  @override
  void disconnect() => disconnectCalls++;

  @override
  void dispose() {
    disposeCalls++;
    unawaited(controller.close());
  }

  void emit(QueueRealtimeSignal signal) => controller.add(signal);
}

class FakeRepository implements QueueRealtimeRepository {
  final FakeConnection connection = FakeConnection();
  final List<(String, String)> createArguments = [];
  int createCalls = 0;

  @override
  QueueRealtimeConnection create({
    required String baseUrl,
    required String path,
  }) {
    createCalls++;
    createArguments.add((baseUrl, path));
    return connection;
  }
}

class FakeTask implements QueueRealtimeScheduledTask {
  FakeTask(this.due, this.callback);

  final DateTime due;
  final void Function() callback;
  bool active = true;

  @override
  void cancel() => active = false;
}

class FakeScheduler implements QueueRealtimeScheduler {
  DateTime now = DateTime.utc(2026);
  final List<FakeTask> tasks = [];

  @override
  QueueRealtimeScheduledTask schedule(
    Duration delay,
    void Function() callback,
  ) {
    final task = FakeTask(now.add(delay), callback);
    tasks.add(task);
    return task;
  }

  void elapse(Duration duration) {
    now = now.add(duration);
    while (true) {
      final due =
          tasks.where((task) => task.active && !task.due.isAfter(now)).toList()
            ..sort((left, right) => left.due.compareTo(right.due));
      if (due.isEmpty) return;
      final task = due.first;
      task.active = false;
      task.callback();
    }
  }
}

class RecordingLogger extends AppLogger {
  int failures = 0;

  @override
  void queueRealtimeFailure(StackTrace stack) => failures++;
}

Future<void> flushMicrotasks() async {
  for (var index = 0; index < 8; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

QueueRealtimeSignal connectedSignal() =>
    const QueueRealtimeSignal.connection(QueueRealtimeSignalType.connected);

QueueRealtimeSignal disconnectedSignal() =>
    const QueueRealtimeSignal.connection(QueueRealtimeSignalType.disconnected);

QueueRealtimeSignal notification(
  String eventType, {
  String targetType = 'SHOP',
  String targetId = '15',
}) => QueueRealtimeSignal.notification(
  QueueRealtimeNotification(
    eventType: eventType,
    targetType: targetType,
    targetId: targetId,
  ),
);

QueueRealtimeCoordinator makeCoordinator({
  required FakeRepository repository,
  required FakeScheduler scheduler,
  required Future<void> Function(List<String>) refresh,
  required bool Function() isCurrent,
  List<String> tabs = const ['pending', 'in-progress'],
  int? shopId = 15,
  bool demo = false,
  String? baseUrl = 'https://socket.example.test',
  RecordingLogger? logger,
}) => QueueRealtimeCoordinator(
  shopId: shopId,
  permittedTabs: tabs,
  demo: demo,
  socketBaseUrl: baseUrl,
  repository: repository,
  isCurrentScope: isCurrent,
  refreshQueue: refresh,
  appLogger: logger ?? RecordingLogger(),
  timerScheduler: scheduler,
);

void main() {
  test(
    'subscribes to the shop and waits for acknowledgement before live state',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      final refreshes = <List<String>>[];
      final ack = Completer<bool>();
      repository.connection.nextSubscribeAck = ack;
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (tabs) async => refreshes.add(tabs),
      );

      coordinator.start();
      expect(repository.createCalls, 1);
      expect(repository.createArguments.single, (
        'https://socket.example.test',
        queueRealtimeSocketPath,
      ));
      expect(repository.connection.connectCalls, 1);
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      expect(repository.connection.subscribedShops, [15]);
      expect(coordinator.status, QueueRealtimeStatus.connecting);

      ack.complete(true);
      await flushMicrotasks();
      expect(coordinator.status, QueueRealtimeStatus.subscribed);
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(refreshes, [
        ['pending', 'in-progress'],
      ]);
      scheduler.elapse(const Duration(seconds: 30));
      await flushMicrotasks();
      expect(refreshes, hasLength(1));
      await coordinator.dispose();
    },
  );

  test('filters shop events and debounces allowed queue reads', () async {
    final repository = FakeRepository();
    final scheduler = FakeScheduler();
    final refreshes = <List<String>>[];
    final coordinator = makeCoordinator(
      repository: repository,
      scheduler: scheduler,
      isCurrent: () => true,
      tabs: const ['pending'],
      refresh: (tabs) async => refreshes.add(tabs),
    );
    coordinator.start();
    repository.connection.emit(connectedSignal());
    await flushMicrotasks();
    scheduler.elapse(Duration.zero);
    await flushMicrotasks();
    refreshes.clear();

    repository.connection.emit(notification('NEW_BOOKING'));
    repository.connection.emit(notification('BOOKING_STARTED'));
    repository.connection.emit(notification('BOOKING_CANCELLED'));
    repository.connection.emit(notification('BOOKING_COMPLETED'));
    repository.connection.emit(notification('OTHER'));
    repository.connection.emit(notification('NEW_BOOKING', targetId: '16'));
    repository.connection.emit(
      notification('BOOKING_STARTED', targetType: 'CUSTOMER'),
    );
    scheduler.elapse(const Duration(milliseconds: 399));
    await flushMicrotasks();
    expect(refreshes, isEmpty);
    scheduler.elapse(const Duration(milliseconds: 1));
    await flushMicrotasks();
    expect(refreshes, [
      ['pending'],
    ]);
    await coordinator.dispose();
  });

  test(
    'trailing read runs when a valid event arrives during an active read',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      final firstRead = Completer<void>();
      var refreshCount = 0;
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (_) {
          refreshCount++;
          return refreshCount == 1 ? firstRead.future : Future.value();
        },
      );
      coordinator.start();
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(refreshCount, 1);

      repository.connection.emit(notification('BOOKING_STARTED'));
      scheduler.elapse(const Duration(milliseconds: 400));
      await flushMicrotasks();
      expect(refreshCount, 1);
      firstRead.complete();
      await flushMicrotasks();
      expect(refreshCount, 2);
      await coordinator.dispose();
    },
  );

  test(
    'reconnect resubscribes and background resume recovers missed events',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      var refreshCount = 0;
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (_) async => refreshCount++,
      );
      coordinator.start();
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(refreshCount, 1);

      repository.connection.emit(disconnectedSignal());
      expect(coordinator.status, QueueRealtimeStatus.disconnected);
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(repository.connection.subscribedShops, [15, 15]);
      expect(refreshCount, 2);

      await coordinator.pause();
      expect(coordinator.status, QueueRealtimeStatus.paused);
      expect(repository.connection.unsubscribedShops, [15]);
      expect(repository.connection.disconnectCalls, 1);
      coordinator.resume();
      expect(repository.connection.connectCalls, 2);
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(repository.connection.subscribedShops, [15, 15, 15]);
      expect(refreshCount, 3);
      await coordinator.dispose();
    },
  );

  test(
    'demo, missing configuration, and empty permission do not open sockets',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      Future<void> noRead(List<String> _) async {}
      var fallbackReads = 0;
      final demo = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: noRead,
        demo: true,
      );
      demo.start();
      expect(demo.status, QueueRealtimeStatus.demo);
      await demo.pause();
      demo.resume();
      expect(demo.status, QueueRealtimeStatus.demo);

      final unconfigured = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (_) async => fallbackReads++,
        baseUrl: null,
      );
      unconfigured.start();
      expect(unconfigured.status, QueueRealtimeStatus.unconfigured);
      scheduler.elapse(queueRealtimePollInterval);
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(fallbackReads, 1);

      final noPermissions = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: noRead,
        tabs: const [],
      );
      noPermissions.start();
      expect(noPermissions.status, QueueRealtimeStatus.disabled);
      expect(repository.createCalls, 0);
      await demo.dispose();
      await unconfigured.dispose();
      await noPermissions.dispose();
    },
  );

  test(
    'stale A to B to A scope events cannot trigger another account read',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      var revision = 1;
      var accountId = 'account-a';
      var shop = 'A';
      var refreshCount = 0;
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () =>
            revision == 1 && accountId == 'account-a' && shop == 'A',
        refresh: (_) async => refreshCount++,
      );
      coordinator.start();
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      expect(refreshCount, 1);

      shop = 'B';
      revision = 2;
      shop = 'A';
      revision = 3;
      repository.connection.emit(notification('NEW_BOOKING'));
      scheduler.elapse(const Duration(milliseconds: 400));
      await flushMicrotasks();
      expect(refreshCount, 1);
      accountId = 'account-b';
      revision = 4;
      repository.connection.emit(notification('BOOKING_STARTED'));
      scheduler.elapse(const Duration(milliseconds: 400));
      await flushMicrotasks();
      expect(refreshCount, 1);
      await coordinator.dispose();
    },
  );

  test(
    'repeated starts keep one listener and disposal unsubscribes once',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      var refreshCount = 0;
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (_) async => refreshCount++,
      );
      coordinator.start();
      coordinator.start();
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      scheduler.elapse(Duration.zero);
      await flushMicrotasks();
      await coordinator.dispose();
      scheduler.elapse(const Duration(seconds: 1));
      expect(repository.createCalls, 1);
      expect(repository.connection.subscribedShops, [15]);
      expect(repository.connection.unsubscribedShops, [15]);
      expect(repository.connection.disconnectCalls, 1);
      expect(repository.connection.disposeCalls, 1);
      expect(refreshCount, 1);
      await coordinator.dispose();
      expect(repository.connection.disposeCalls, 1);
    },
  );

  test(
    'transport failures expose no exception content or mutation behavior',
    () async {
      final repository = FakeRepository();
      final scheduler = FakeScheduler();
      final logger = RecordingLogger();
      final coordinator = makeCoordinator(
        repository: repository,
        scheduler: scheduler,
        isCurrent: () => true,
        refresh: (_) async {},
        logger: logger,
      );
      repository.connection.throwOnSubscribe = true;
      coordinator.start();
      repository.connection.emit(connectedSignal());
      await flushMicrotasks();
      expect(coordinator.status, QueueRealtimeStatus.unavailable);
      expect(logger.failures, 1);
      expect(repository.connection.subscribedShops, [15]);
      expect(repository.connection.unsubscribedShops, isEmpty);
      await coordinator.dispose();
    },
  );
}
