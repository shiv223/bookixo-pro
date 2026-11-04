import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/salon_preference_repository.dart';

abstract interface class SalonPreferenceBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSalonPreferenceBackend implements SalonPreferenceBackend {
  const PlatformSalonPreferenceBackend(this.storage);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

/// Serial transactions include a post-write ownership check and rollback.
class SalonPreferenceRepositoryImpl implements SalonPreferenceRepository {
  SalonPreferenceRepositoryImpl(this.storage);
  final SalonPreferenceBackend storage;
  Future<void> _tail = Future.value();

  String _key(String account) =>
      'bookixo.salon.v1.${base64Url.encode(utf8.encode(account))}';

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<int?> read(String account) => _serial(() async {
    try {
      final value = await storage.read(_key(account));
      return value == null ? null : int.tryParse(value);
    } on PlatformException catch (_, stack) {
      Error.throwWithStackTrace(const StorageFailure(), stack);
    } on MissingPluginException catch (_, stack) {
      Error.throwWithStackTrace(const StorageFailure(), stack);
    }
  });

  @override
  Future<void> write(String account, int shopId, bool Function() isCurrent) =>
      _serial(() async {
        if (!isCurrent()) return;
        try {
          final key = _key(account);
          final previous = await storage.read(key);
          if (!isCurrent()) return;
          await storage.write(key, '$shopId');
          if (!isCurrent()) {
            if (previous == null) {
              await storage.delete(key);
            } else {
              await storage.write(key, previous);
            }
          }
        } on PlatformException catch (_, stack) {
          Error.throwWithStackTrace(const StorageFailure(), stack);
        } on MissingPluginException catch (_, stack) {
          Error.throwWithStackTrace(const StorageFailure(), stack);
        }
      });
}
