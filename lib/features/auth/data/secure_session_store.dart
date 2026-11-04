import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/data_failure_mapper.dart';
import '../domain/auth_models.dart';
import 'sign_in_response_dto.dart';

/// Injectable secure backend for deterministic storage/race tests.
abstract interface class SecureBackend {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class PlatformSecureBackend implements SecureBackend {
  const PlatformSecureBackend(this.storage);
  final FlutterSecureStorage storage;
  static const key = 'bookixo.session.v1';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> delete() => storage.delete(key: key);
}

/// Serializes reads, writes and deletion; guard executes inside the queue.
class SecureSessionStore {
  SecureSessionStore(this.backend);
  final SecureBackend backend;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    // Errors stay on the caller's result; only the internal queue recovers.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<AuthSession?> read() => _serial(() async {
    try {
      final raw = await backend.read();
      if (raw == null) return null;
      final bundle = jsonDecode(raw);
      if (bundle is! Map<String, Object?> ||
          bundle['version'] != 1 ||
          bundle['receivedAt'] is! String) {
        throw const ContractFailure();
      }
      final receivedAt = DateTime.parse(bundle['receivedAt'] as String);
      final outcome = SignInResponseDto.parse(bundle['response'])
          .toOutcome(receivedAt);
      if (outcome is! Authenticated) throw const ContractFailure();
      return outcome.session;
    } on FormatException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s), s);
    } on PlatformException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    } on MissingPluginException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    }
  });

  Future<bool> write(
    AuthSession session,
    bool Function() current,
  ) => _serial(() async {
    if (!current()) return false;
    final t = session.tokens;
    final bundle = jsonEncode({
      'version': 1,
      'receivedAt': t.receivedAt.toIso8601String(),
      'response': {
        'accessToken': t.accessToken,
        'idToken': t.idToken,
        'refreshToken': t.refreshToken,
        'expiresIn': t.expiresIn,
        'tokenType': 'Bearer',
        'userId': session.identity.userId,
        'email': session.identity.email,
      },
    });
    try {
      await backend.write(bundle);
      return current();
    } on PlatformException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    } on MissingPluginException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    }
  });

  Future<void> clear() => _serial(() async {
    try {
      await backend.delete();
    } on PlatformException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    } on MissingPluginException catch (e, s) {
      Error.throwWithStackTrace(DataFailureMapper.map(e, s, storage: true), s);
    }
  });
}
