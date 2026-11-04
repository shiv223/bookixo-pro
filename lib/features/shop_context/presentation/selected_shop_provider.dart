import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/shop_context.dart';
import 'shop_context_controller.dart';
import 'salon_selection_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';

/// Only validated shop IDs can scope menu requests.
final selectedShopProvider = Provider<Shop?>((ref) {
  final context = ref.watch(shopContextProvider).asData?.value;
  if (context == null) return null;
  if (context.shops.length == 1) return context.shops.single;
  final id = ref.watch(configProvider).demo
      ? ref.watch(demoShopSelectionProvider)
      : ref.watch(salonSelectionProvider).id;
  for (final shop in context.shops) {
    if (shop.id == id && shop.id > 0) return shop;
  }
  return null;
});
