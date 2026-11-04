import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../../core/logging/app_logger.dart';
import 'queue_realtime_dto.dart';
import '../domain/queue_realtime_repository.dart';

/// Socket.IO transport for the booking queue gateway.
class SocketIoQueueRealtimeRepository implements QueueRealtimeRepository {
  const SocketIoQueueRealtimeRepository(this._logger);
  final AppLogger _logger;

  @override
  QueueRealtimeConnection create({
    required String baseUrl,
    required String path,
  }) {
    try {
      return _SocketIoQueueRealtimeConnection(baseUrl, path, _logger);
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
      return _UnavailableQueueRealtimeConnection();
    }
  }
}

class _SocketIoQueueRealtimeConnection implements QueueRealtimeConnection {
  _SocketIoQueueRealtimeConnection(String baseUrl, String path, this._logger)
    : _socket = socket_io.io(
        baseUrl,
        socket_io.OptionBuilder()
            .setTransports(const ['websocket'])
            .setPath(path)
            .disableAutoConnect()
            .enableReconnection()
            .enableForceNew()
            .build(),
      ) {
    _removeListeners.addAll([
      _socket.on('connect', _handleConnected),
      _socket.on('disconnect', _handleDisconnected),
      _socket.on('connect_error', _handleConnectionError),
      _socket.on('notification', _handleNotification),
    ]);
  }

  static const _ackTimeout = Duration(seconds: 5);
  final AppLogger _logger;
  final socket_io.Socket _socket;
  final StreamController<QueueRealtimeSignal> _signals =
      StreamController<QueueRealtimeSignal>.broadcast(sync: true);
  final List<Function()> _removeListeners = [];
  final Set<Timer> _ackTimers = {};
  final Set<Completer<bool>> _pendingAcknowledgements = {};
  bool _disposed = false;

  @override
  Stream<QueueRealtimeSignal> get signals => _signals.stream;

  @override
  void connect() {
    if (_disposed) return;
    try {
      _socket.connect();
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
      _emit(
        const QueueRealtimeSignal.connection(
          QueueRealtimeSignalType.connectionError,
        ),
      );
    }
  }

  @override
  Future<bool> subscribe(int shopId) =>
      _emitScopedAck('subscribe', shopId, 'subscribed');

  @override
  Future<bool> unsubscribe(int shopId) =>
      _emitScopedAck('unsubscribe', shopId, 'unsubscribed');

  Future<bool> _emitScopedAck(
    String event,
    int shopId,
    String expectedEvent,
  ) async {
    if (_disposed || !_socket.connected) return false;
    final scope = QueueRealtimeScopeDto(shopId);
    final completer = Completer<bool>();
    final timer = Timer(_ackTimeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    _ackTimers.add(timer);
    _pendingAcknowledgements.add(completer);
    try {
      _socket.emitWithAck(
        event,
        scope.toJson(),
        ack: (Object? response) {
          if (completer.isCompleted) return;
          completer.complete(
            scope.matchesAcknowledgement(response, expectedEvent),
          );
        },
      );
      return await completer.future;
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
      _emit(
        const QueueRealtimeSignal.connection(
          QueueRealtimeSignalType.connectionError,
        ),
      );
      return false;
    } finally {
      timer.cancel();
      _ackTimers.remove(timer);
      _pendingAcknowledgements.remove(completer);
    }
  }

  void _handleConnected(Object? _) {
    _emit(
      const QueueRealtimeSignal.connection(QueueRealtimeSignalType.connected),
    );
  }

  void _handleDisconnected(Object? _) {
    _cancelPendingAcknowledgements();
    _emit(
      const QueueRealtimeSignal.connection(
        QueueRealtimeSignalType.disconnected,
      ),
    );
  }

  void _handleConnectionError(Object? _) {
    _emit(
      const QueueRealtimeSignal.connection(
        QueueRealtimeSignalType.connectionError,
      ),
    );
  }

  void _handleNotification(Object? value) {
    final notification = parseQueueRealtimeNotification(value);
    if (notification != null) {
      _emit(QueueRealtimeSignal.notification(notification));
    }
  }

  void _emit(QueueRealtimeSignal signal) {
    if (!_disposed && !_signals.isClosed) _signals.add(signal);
  }

  @override
  void disconnect() {
    if (_disposed) return;
    _cancelPendingAcknowledgements();
    try {
      _socket.disconnect();
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPendingAcknowledgements();
    for (final removeListener in _removeListeners) {
      removeListener();
    }
    _removeListeners.clear();
    try {
      _socket.dispose();
    } on Object catch (_, stackTrace) {
      _logger.queueRealtimeFailure(stackTrace);
    }
    unawaited(_signals.close());
  }

  void _cancelPendingAcknowledgements() {
    for (final timer in _ackTimers.toList()) {
      timer.cancel();
    }
    _ackTimers.clear();
    for (final acknowledgement in _pendingAcknowledgements.toList()) {
      if (!acknowledgement.isCompleted) acknowledgement.complete(false);
    }
    _pendingAcknowledgements.clear();
  }
}

class _UnavailableQueueRealtimeConnection implements QueueRealtimeConnection {
  @override
  Stream<QueueRealtimeSignal> get signals => Stream.value(
    const QueueRealtimeSignal.connection(
      QueueRealtimeSignalType.connectionError,
    ),
  );

  @override
  void connect() {}

  @override
  Future<bool> subscribe(int shopId) async => false;

  @override
  Future<bool> unsubscribe(int shopId) async => false;

  @override
  void disconnect() {}

  @override
  void dispose() {}
}
