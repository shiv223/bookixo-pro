import 'dart:async';

/// Time and scheduling seam: mobile timers are hints, not expiry authority.
abstract interface class SessionClock {
  DateTime now();
  void Function() schedule(Duration delay, void Function() callback);
}

class SystemSessionClock implements SessionClock {
  const SystemSessionClock();
  @override
  DateTime now() => DateTime.now().toUtc();
  @override
  void Function() schedule(Duration delay, void Function() callback) {
    final timer = Timer(delay, callback);
    return timer.cancel;
  }
}
