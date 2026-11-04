import 'menu_snapshot.dart';

/// Menu transport and scoped durable snapshot boundary.
abstract interface class MenuRepository {
  Future<MenuSnapshot> fetch(MenuScope scope);
  Future<MenuSnapshot?> read(MenuScope scope);
  Future<void> write(MenuSnapshot snapshot, bool Function() current);
  Future<void> clear();
}
