/// Supported booking events that may invalidate the queue projection.
const queueRealtimeEventTypes = <String>{
  'NEW_BOOKING',
  'BOOKING_STARTED',
  'BOOKING_CANCELLED',
  'BOOKING_COMPLETED',
};
const queueRealtimeSocketPath = '/socket.io';
const queueRealtimePollInterval = Duration(seconds: 15);

/// Lifecycle events emitted by a Socket.IO connection.
enum QueueRealtimeSignalType {
  connected,
  disconnected,
  connectionError,
  notification,
}

/// Sanitized connection signal; notification payloads and customer data are
/// intentionally not retained by the mobile client.
class QueueRealtimeSignal {
  const QueueRealtimeSignal.connection(this.type) : notification = null;
  const QueueRealtimeSignal.notification(this.notification)
    : type = QueueRealtimeSignalType.notification;

  final QueueRealtimeSignalType type;
  final QueueRealtimeNotification? notification;
}

/// Only the three routing fields needed to decide whether to refresh.
class QueueRealtimeNotification {
  const QueueRealtimeNotification({
    required this.eventType,
    required this.targetType,
    required this.targetId,
  });

  final String eventType;
  final String targetType;
  final String targetId;
}

/// A Socket.IO connection scoped to one validated shop.
abstract interface class QueueRealtimeConnection {
  Stream<QueueRealtimeSignal> get signals;
  void connect();
  Future<bool> subscribe(int shopId);
  Future<bool> unsubscribe(int shopId);
  void disconnect();
  void dispose();
}

/// Creates isolated, unauthenticated Socket.IO connections.
abstract interface class QueueRealtimeRepository {
  QueueRealtimeConnection create({
    required String baseUrl,
    required String path,
  });
}
