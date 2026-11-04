import '../domain/queue_realtime_repository.dart';

/// Wire representation for subscribing to a single shop room.
class QueueRealtimeScopeDto {
  const QueueRealtimeScopeDto(this.shopId);

  final int shopId;

  Map<String, String> toJson() => {
    'targetType': 'SHOP',
    'targetId': shopId.toString(),
  };

  bool matchesAcknowledgement(Object? response, String eventName) {
    if (response is! Map<Object?, Object?>) return false;
    return response['room'] == 'SHOP:$shopId' &&
        response['targetType'] == 'SHOP' &&
        response['targetId'] == shopId.toString() &&
        (eventName == 'subscribed' || eventName == 'unsubscribed');
  }
}

/// Drops the opaque server payload and retains only routing fields.
QueueRealtimeNotification? parseQueueRealtimeNotification(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  final eventType = value['eventType'];
  final targetType = value['targetType'];
  final targetId = value['targetId'];
  if (eventType is! String || targetType is! String || targetId is! String) {
    return null;
  }
  return QueueRealtimeNotification(
    eventType: eventType,
    targetType: targetType,
    targetId: targetId,
  );
}
