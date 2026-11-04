import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../../auth/data/secure_session_store.dart';
import '../domain/menu_snapshot.dart';

/// Uses a separate key, with the existing injectable secure backend protocol.
class MenuSecureBackend implements SecureBackend {
  const MenuSecureBackend(this.storage);
  final FlutterSecureStorage storage;
  // Keep the storage slot so v1 flat snapshots can migrate to schema v2.
  static const key = 'bookixo.menu.v1';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}

/// Serialized durable IO. Clear invalidates queued writes synchronously.
class MenuCacheStore {
  MenuCacheStore(this.backend);
  final SecureBackend backend;
  Future<void>? _tail;
  int _generation = 0;
  Future<T> _serial<T>(Future<T> Function() operation) {
    final tail = _tail;
    final result = tail == null ? operation() : tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<MenuSnapshot?> read(MenuScope scope) => _serial(() async {
    try {
      final raw = await backend.read();
      if (raw == null) return null;
      final bundle = jsonDecode(raw);
      if (bundle is! Map<String, Object?> ||
          (bundle['version'] != 1 &&
              bundle['version'] != MenuSnapshot.schemaVersion) ||
          bundle['userId'] is! String ||
          (bundle['userId'] as String).isEmpty ||
          (bundle['subject'] != null && bundle['subject'] is! String) ||
          bundle['shopId'] is! int ||
          (bundle['shopId'] as int) <= 0 ||
          bundle['fetchedAt'] is! String ||
          bundle['keys'] is! List) {
        throw const ContractFailure();
      }
      final keys = <String>{};
      for (final key in bundle['keys'] as List) {
        if (key is! String || key.trim().isEmpty) throw const ContractFailure();
        keys.add(key);
      }
      // v1 is deliberately flat-only. Never infer edges from key co-presence.
      final children = <String>{};
      if (bundle['version'] == MenuSnapshot.schemaVersion) {
        final rawChildren = bundle['shopSetupChildren'];
        if (rawChildren is! List) throw const ContractFailure();
        for (final child in rawChildren) {
          if (child is! String ||
              child.trim().isEmpty ||
              !keys.contains(child) ||
              !keys.contains('shop-setup')) {
            throw const ContractFailure();
          }
          children.add(child);
        }
      }
      final owner = MenuScope(
        bundle['userId'] as String,
        bundle['subject'] as String?,
        bundle['shopId'] as int,
      );
      final date = DateTime.parse(bundle['fetchedAt'] as String);
      return owner == scope
          ? MenuSnapshot(owner, keys, date, shopSetupChildren: children)
          : null;
    } catch (e, s) {
      Error.throwWithStackTrace(
        DataFailureMapper.map(
          e,
          s,
          storage: e is! FormatException && e is! AppFailure,
        ),
        s,
      );
    }
  });
  Future<void> write(MenuSnapshot snapshot, bool Function() current) {
    final generation = _generation;
    return _serial(() async {
      if (generation != _generation || !current()) return;
      try {
        await backend.write(
          jsonEncode({
            'version': MenuSnapshot.schemaVersion,
            'userId': snapshot.scope.userId,
            'subject': snapshot.scope.subject,
            'shopId': snapshot.scope.shopId,
            'fetchedAt': snapshot.fetchedAt.toIso8601String(),
            'keys': snapshot.keys.toList()..sort(),
            'shopSetupChildren': snapshot.shopSetupChildren.toList()..sort(),
          }),
        );
      } catch (e, s) {
        Error.throwWithStackTrace(
          DataFailureMapper.map(e, s, storage: true),
          s,
        );
      }
    });
  }

  Future<void> clear() {
    ++_generation;
    return _serial(() async {
      try {
        await backend.delete();
      } catch (e, s) {
        Error.throwWithStackTrace(
          DataFailureMapper.map(e, s, storage: true),
          s,
        );
      }
    });
  }
}
