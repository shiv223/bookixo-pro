import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import 'menu_controller.dart';

/// Explicit switches are distinct even when lazy consumers observe only A again.
final salonSwitchRevisionProvider = NotifierProvider<SalonSwitchRevision, int>(
  SalonSwitchRevision.new,
);

class SalonSwitchRevision extends Notifier<int> {
  @override
  int build() => 0;
  void advance() => state++;
}

/// Monotonic identity for requests and local drafts, including A -> B -> A.
final scopeRevisionProvider = NotifierProvider<ScopeRevision, int>(
  ScopeRevision.new,
);

class ScopeRevision extends Notifier<int> {
  int _revision = 0;
  @override
  int build() {
    ref.watch(menuScopeProvider);
    ref.watch(salonSwitchRevisionProvider);
    ref.watch(
      authControllerProvider.select((auth) => auth.asData?.value.ownership),
    );
    return ++_revision;
  }
}
