import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../domain/queue_realtime_repository.dart';

/// User-visible state of the optional live queue connection.
enum QueueRealtimeStatus {
  disabled,
  demo,
  unconfigured,
  connecting,
  subscribed,
  disconnected,
  unavailable,
  paused,
}

/// Injectable timer surface for deterministic debounce and trailing-read tests.
abstract interface class QueueRealtimeScheduler {
  QueueRealtimeScheduledTask schedule(Duration delay, void Function() callback);
}

abstract interface class QueueRealtimeScheduledTask {
  void cancel();
}

class SystemQueueRealtimeScheduler implements QueueRealtimeScheduler {
  const SystemQueueRealtimeScheduler();

  @override
  QueueRealtimeScheduledTask schedule(
    Duration delay,
    void Function() callback,
  ) => _SystemQueueRealtimeTask(Timer(delay, callback));
}

class _SystemQueueRealtimeTask implements QueueRealtimeScheduledTask {
  const _SystemQueueRealtimeTask(this._timer);
  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

typedef QueueRefresh = Future<void> Function(List<String> permittedTabs);

/// Owns one shop-scoped Socket.IO connection and debounced REST invalidations.
class QueueRealtimeCoordinator {
  QueueRealtimeCoordinator({
    required int? shopId,
    required List<String> permittedTabs,
    required bool demo,
    required String? socketBaseUrl,
    required QueueRealtimeRepository? repository,
    required bool Function() isCurrentScope,
    required QueueRefresh refreshQueue,
    required AppLogger appLogger,
    QueueRealtimeScheduler timerScheduler =
        const SystemQueueRealtimeScheduler(),
    this.debounceDuration = const Duration(milliseconds: 400),
    this.pollInterval = queueRealtimePollInterval,
  }) : _shopId = shopId,
       _permittedTabs = List.unmodifiable(permittedTabs),
       _demo = demo,
       _isCurrent = isCurrentScope,
       _refresh = refreshQueue,
       _logger = appLogger,
       _scheduler = timerScheduler,
       _repository = repository,
       _socketBaseUrl = socketBaseUrl,
       _status = demo
           ? QueueRealtimeStatus.demo
           : shopId == null || permittedTabs.isEmpty
           ? QueueRealtimeStatus.disabled
           : socketBaseUrl == null || repository == null
           ? QueueRealtimeStatus.unconfigured
           : QueueRealtimeStatus.connecting;

  final int? _shopId;
  final List<String> _permittedTabs;
  final bool _demo;
  final bool Function() _isCurrent;
  final QueueRefresh _refresh;
  final AppLogger _logger;
  final QueueRealtimeScheduler _scheduler;
  final QueueRealtimeRepository? _repository;
  final String? _socketBaseUrl;
  final Duration debounceDuration;
  final Duration pollInterval;
  final StreamController<QueueRealtimeStatus> _statusChanges =
      StreamController<QueueRealtimeStatus>.broadcast(sync: true);

  QueueRealtimeConnection? _connection;
  StreamSubscription<QueueRealtimeSignal>? _signalsSubscription;
  QueueRealtimeScheduledTask? _debounceTask;
  QueueRealtimeScheduledTask? _pollTask;
  QueueRealtimeStatus _status;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;
  bool _subscribed = false;
  bool _refreshPending = false;
  bool _refreshRunning = false;
  int _connectionGeneration = 0;

  QueueRealtimeStatus get status => _status;
  bool get isSubscribed => _status == QueueRealtimeStatus.subscribed;
  Stream<QueueRealtimeStatus> get statusChanges => Stream.multi((controller) {
    final subscription = _statusChanges.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.add(_status);
    controller.onCancel = subscription.cancel;
  });

  void start() {
    if (_started || _disposed || _status == QueueRealtimeStatus.disabled) {
      return;
    }
    _started = true;
    _scheduleFallbackPoll();
    if (_status == QueueRealtimeStatus.demo ||
        _status == QueueRealtimeStatus.unconfigured) {
      return;
    }
    final repository = _repository;
    final baseUrl = _socketBaseUrl;
    if (repository == null || baseUrl == null || !_isActive) return;
    try {
      final connection = repository.create(
        baseUrl: baseUrl,
        path: queueRealtimeSocketPath,
      );
      _connection = connection;
      _signalsSubscription = connection.signals.listen(
        _onSignal,
        onError: (Object error, StackTrace stackTrace) {
          _logger.queueRealtimeFailure(stackTrace);
          if (_isActive) _setStatus(QueueRealtimeStatus.unavailable);
        },
      );
      connection.connect();
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
      _setStatus(QueueRealtimeStatus.unavailable);
    }
  }

  bool get _isActive =>
      !_disposed && !_paused && _isCurrent() && _permittedTabs.isNotEmpty;

  void _onSignal(QueueRealtimeSignal signal) {
    if (!_isActive) return;
    switch (signal.type) {
      case QueueRealtimeSignalType.connected:
        _subscribed = false;
        final generation = ++_connectionGeneration;
        _setStatus(QueueRealtimeStatus.connecting);
        unawaited(_subscribe(generation));
      case QueueRealtimeSignalType.disconnected:
        _subscribed = false;
        _connectionGeneration++;
        _setStatus(QueueRealtimeStatus.disconnected);
      case QueueRealtimeSignalType.connectionError:
        _subscribed = false;
        _connectionGeneration++;
        _setStatus(QueueRealtimeStatus.unavailable);
      case QueueRealtimeSignalType.notification:
        _onNotification(signal.notification);
    }
  }

  Future<void> _subscribe(int generation) async {
    final connection = _connection;
    final shopId = _shopId;
    if (connection == null || shopId == null || !_isActive) return;
    try {
      final acknowledged = await connection.subscribe(shopId);
      if (!_isActive || generation != _connectionGeneration) return;
      if (!acknowledged) {
        _subscribed = false;
        _setStatus(QueueRealtimeStatus.unavailable);
        return;
      }
      _subscribed = true;
      _setStatus(QueueRealtimeStatus.subscribed);
      _requestRefresh(immediate: true);
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
      if (_isActive && generation == _connectionGeneration) {
        _subscribed = false;
        _setStatus(QueueRealtimeStatus.unavailable);
      }
    }
  }

  void _onNotification(QueueRealtimeNotification? notification) {
    if (!_subscribed || notification == null || !_isActive) return;
    if (!queueRealtimeEventTypes.contains(notification.eventType) ||
        notification.targetType != 'SHOP' ||
        notification.targetId != _shopId.toString()) {
      return;
    }
    _requestRefresh();
  }

  void _requestRefresh({bool immediate = false}) {
    if (!_isActive || _permittedTabs.isEmpty) return;
    _refreshPending = true;
    _debounceTask?.cancel();
    _debounceTask = _scheduler.schedule(
      immediate ? Duration.zero : debounceDuration,
      () {
        _debounceTask = null;
        unawaited(_flushRefresh());
      },
    );
  }

  void _scheduleFallbackPoll() {
    if (_disposed ||
        _paused ||
        !_isCurrent() ||
        _permittedTabs.isEmpty ||
        _status == QueueRealtimeStatus.subscribed ||
        _status == QueueRealtimeStatus.disabled ||
        _pollTask != null) {
      return;
    }
    _pollTask = _scheduler.schedule(pollInterval, () {
      _pollTask = null;
      if (_disposed ||
          _paused ||
          !_isCurrent() ||
          _status == QueueRealtimeStatus.subscribed) {
        return;
      }
      _requestRefresh(immediate: true);
      _scheduleFallbackPoll();
    });
  }

  Future<void> _flushRefresh() async {
    if (_disposed || !_isCurrent() || !_refreshPending || _refreshRunning) {
      return;
    }
    _refreshPending = false;
    _refreshRunning = true;
    try {
      await _refresh(_permittedTabs);
    } on Object catch (_, stackTrace) {
      // Queue providers retain the typed read error for their Retry UI.
      _logger.queueRealtimeFailure(stackTrace);
    } finally {
      _refreshRunning = false;
      if (_refreshPending && _debounceTask == null && !_disposed) {
        unawaited(_flushRefresh());
      }
    }
  }

  /// Reconnects after foregrounding; the subscription acknowledgement
  /// triggers an authoritative REST refresh to recover missed notifications.
  void resume() {
    if (_disposed || !_isCurrent() || _status == QueueRealtimeStatus.disabled) {
      return;
    }
    _paused = false;
    if (_demo) {
      _setStatus(QueueRealtimeStatus.demo);
      _scheduleFallbackPoll();
      return;
    }
    if (_socketBaseUrl == null || _repository == null) {
      _setStatus(QueueRealtimeStatus.unconfigured);
      _scheduleFallbackPoll();
      return;
    }
    if (_connection == null) {
      start();
      return;
    }
    if (_subscribed) {
      _requestRefresh(immediate: true);
      return;
    }
    _setStatus(QueueRealtimeStatus.connecting);
    _connection?.connect();
  }

  /// Unsubscribes before closing the transport while the app is backgrounded.
  Future<void> pause() {
    if (_disposed || _paused || _status == QueueRealtimeStatus.disabled) {
      return Future.value();
    }
    _paused = true;
    _debounceTask?.cancel();
    _debounceTask = null;
    _pollTask?.cancel();
    _pollTask = null;
    _refreshPending = false;
    final wasSubscribed = _subscribed;
    _subscribed = false;
    _connectionGeneration++;
    _setStatus(QueueRealtimeStatus.paused);
    _closeTransport(unsubscribe: wasSubscribed);
    return Future.value();
  }

  /// Allows a user to retry after a transient connect or subscribe failure.
  void retry() {
    if (_disposed ||
        !_isCurrent() ||
        _status == QueueRealtimeStatus.demo ||
        _status == QueueRealtimeStatus.unconfigured ||
        _status == QueueRealtimeStatus.disabled) {
      return;
    }
    _paused = false;
    _setStatus(QueueRealtimeStatus.connecting);
    if (_connection == null) {
      _started = false;
      start();
    } else {
      _connection?.connect();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTask?.cancel();
    _debounceTask = null;
    _pollTask?.cancel();
    _pollTask = null;
    _refreshPending = false;
    final wasSubscribed = _subscribed;
    _subscribed = false;
    _connectionGeneration++;
    _closeTransport(unsubscribe: wasSubscribed);
    await _signalsSubscription?.cancel();
    _signalsSubscription = null;
    _connection?.dispose();
    _connection = null;
    await _statusChanges.close();
  }

  void _closeTransport({required bool unsubscribe}) {
    final connection = _connection;
    final shopId = _shopId;
    if (connection == null) return;
    if (unsubscribe && shopId != null) {
      try {
        final operation = connection.unsubscribe(shopId);
        unawaited(
          operation.then<void>(
            (_) {},
            onError: (Object error, StackTrace stackTrace) {
              _logger.queueRealtimeFailure(stackTrace);
            },
          ),
        );
      } on Object catch (_, stackTrace) {
        _logger.queueRealtimeFailure(stackTrace);
      }
    }
    connection.disconnect();
  }

  void _setStatus(QueueRealtimeStatus next) {
    if (_status == next || _disposed || _statusChanges.isClosed) return;
    _status = next;
    _statusChanges.add(next);
    if (next == QueueRealtimeStatus.subscribed ||
        next == QueueRealtimeStatus.paused ||
        next == QueueRealtimeStatus.disabled) {
      _pollTask?.cancel();
      _pollTask = null;
    } else {
      _scheduleFallbackPoll();
    }
  }
}
