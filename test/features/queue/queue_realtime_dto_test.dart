import 'package:bookixo_pro/features/queue/data/queue_realtime_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subscription payload and acknowledgement stay shop-scoped', () {
    const scope = QueueRealtimeScopeDto(42);
    expect(scope.toJson(), {'targetType': 'SHOP', 'targetId': '42'});
    expect(
      scope.matchesAcknowledgement({
        'room': 'SHOP:42',
        'targetType': 'SHOP',
        'targetId': '42',
      }, 'subscribed'),
      isTrue,
    );
    expect(
      scope.matchesAcknowledgement({
        'room': 'SHOP:43',
        'targetType': 'SHOP',
        'targetId': '42',
      }, 'subscribed'),
      isFalse,
    );
    expect(
      scope.matchesAcknowledgement({
        'room': 'SHOP:42',
        'targetType': 'CUSTOMER',
        'targetId': '42',
      }, 'subscribed'),
      isFalse,
    );
    expect(
      scope.matchesAcknowledgement({
        'room': 'SHOP:42',
        'targetType': 'SHOP',
        'targetId': '42',
      }, 'unexpected'),
      isFalse,
    );
  });

  test('notification adapter drops payload and optional customer fields', () {
    final parsed = parseQueueRealtimeNotification({
      'eventType': 'NEW_BOOKING',
      'targetType': 'SHOP',
      'targetId': '42',
      'payload': {'customerName': 'must not be retained'},
      'idempotencyKey': 'ignored',
    });
    expect(parsed?.eventType, 'NEW_BOOKING');
    expect(parsed?.targetType, 'SHOP');
    expect(parsed?.targetId, '42');
    expect(
      parseQueueRealtimeNotification({
        'eventType': 'NEW_BOOKING',
        'targetType': 'SHOP',
        'targetId': 42,
      }),
      isNull,
    );
  });
}
