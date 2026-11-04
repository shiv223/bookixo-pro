import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screens register their actual local dirty/busy state, including dialogs.
/// Request leases survive widget disposal until the mutation settles.
class SalonSwitchGuard extends ChangeNotifier {
  final _drafts = <Object, bool Function()>{};
  int _requests = 0;
  bool _disposed = false;
  bool get busy => _requests > 0;
  bool get dirty => _drafts.values.any((read) => read());

  void register(Object owner, bool Function() dirty) => _drafts[owner] = dirty;
  void unregister(Object owner) => _drafts.remove(owner);

  VoidCallback beginRequest() {
    _requests++;
    if (!_disposed) notifyListeners();
    var finished = false;
    return () {
      if (finished) return;
      finished = true;
      _requests--;
      if (!_disposed) notifyListeners();
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _drafts.clear();
    super.dispose();
  }
}

final salonSwitchGuardProvider = Provider<SalonSwitchGuard>((ref) {
  final guard = SalonSwitchGuard();
  ref.onDispose(guard.dispose);
  return guard;
});
