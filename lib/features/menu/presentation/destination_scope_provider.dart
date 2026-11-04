import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/menu_snapshot.dart';
import 'menu_controller.dart';
import 'scope_revision_provider.dart';

typedef DestinationScope = ({MenuScope menu, int revision});

/// Exact server permission and validated account/shop/login ownership.
/// The revision also distinguishes rapid A -> B -> A salon switches.
final destinationScopeProvider = Provider.family<DestinationScope?, String>((
  ref,
  key,
) {
  final revision = ref.watch(scopeRevisionProvider);
  final scope = ref.watch(menuScopeProvider);
  final permitted = ref.watch(
    menuControllerProvider.select((value) {
      final snapshot = value.asData?.value?.snapshot;
      return scope != null &&
          snapshot?.scope == scope &&
          snapshot?.keys.contains(key) == true;
    }),
  );
  return scope == null || scope.shopId <= 0 || !permitted
      ? null
      : (menu: scope, revision: revision);
});
