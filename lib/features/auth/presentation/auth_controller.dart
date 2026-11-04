import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/session_access.dart';
import '../../menu/presentation/menu_dependencies.dart';
import 'login_controller.dart';
import 'auth_dependencies.dart';

/// Public session view deliberately excludes credentials.
class AuthView {
  const AuthView(
    this.identity,
    this.generation, {
    this.notice,
    this.actionRequired = false,
    this.renewing = false,
    this.locked = false,
    this.ownership = 0,
  });
  final AuthIdentity? identity;
  final int generation;
  final AppFailure? notice;
  final bool actionRequired;
  final bool renewing;
  final bool locked;

  /// Changes only on login/logout/account replacement, never token renewal.
  final int ownership;
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthView>(
  AuthController.new,
  retry: (_, _) => null,
);

/// One lifecycle owner coordinates all renewal triggers and session replacement.
class AuthController extends AsyncNotifier<AuthView> implements SessionAccess {
  AuthSession? _session;
  AuthView _view = const AuthView(null, 0);
  int _generation = 0;
  int _ownership = 0;
  int _revision = 0;
  Future<void>? _renewal;
  void Function()? _cancelTimer;
  bool _logoutPending = false;
  @override
  int get generation => _generation;
  @override
  AuthSession? get currentSession => _logoutPending ? null : _session;

  @override
  Future<AuthView> build() async {
    ref.onDispose(() => _cancelTimer?.call());
    return _restore();
  }

  Future<AuthView> _restore() async {
    final generation = _generation;
    try {
      return await _restoreGeneration(generation);
    } on AppFailure {
      if (generation != _generation || !ref.mounted) return _view;
      rethrow;
    }
  }

  Future<AuthView> _restoreGeneration(int generation) async {
    final repository = ref.read(authRepositoryProvider);
    var session = await repository.restore();
    if (generation != _generation || !ref.mounted) return _view;
    if (session != null && _due(session)) {
      try {
        final outcome = await repository.refresh(session);
        if (generation != _generation || !ref.mounted) return _view;
        if (outcome is Superseded) return _view;
        if (outcome is ActionRequired) {
          _logoutPending = true;
          await _clearSessionData();
          if (generation != _generation || !ref.mounted) return _view;
          _logoutPending = false;
          _view = AuthView(null, ++_revision, actionRequired: true);
          return _view;
        }
        session = outcome is Authenticated ? outcome.session : null;
      } on UnauthorizedFailure {
        if (generation != _generation || !ref.mounted) return _view;
        _logoutPending = true;
        await _clearSessionData();
        if (generation != _generation || !ref.mounted) return _view;
        _logoutPending = false;
        session = null;
      } on ForbiddenFailure {
        if (generation != _generation || !ref.mounted) return _view;
        _logoutPending = true;
        await _clearSessionData();
        if (generation != _generation || !ref.mounted) return _view;
        _logoutPending = false;
        session = null;
      }
    }
    if (generation != _generation || !ref.mounted) return _view;
    if (session != null &&
        !session.tokens.usable(ref.read(clockProvider).now())) {
      _logoutPending = true;
      await _clearSessionData();
      if (generation != _generation || !ref.mounted) return _view;
      _logoutPending = false;
      session = null;
    }
    if (generation != _generation || !ref.mounted) return _view;
    _session = session;
    _view = AuthView(session?.identity, _generation, ownership: _ownership);
    _schedule();
    return _view;
  }

  Future<void> retry() async {
    if (_logoutPending) {
      await logout();
      return;
    }
    if (_session != null) {
      try {
        await ensureFresh(force: true);
      } on AppFailure {
        // Renewal already publishes notice/error or a locked logout failure.
        return;
      }
      return;
    }
    state = const AsyncLoading();
    try {
      final view = await _restore();
      if (ref.mounted) state = AsyncData(view);
    } on AppFailure catch (e, s) {
      if (ref.mounted) state = AsyncError(e, s);
    }
  }

  Future<SignInOutcome> signIn(String identifier, String password) async {
    if (_logoutPending) throw const StorageFailure();
    final generation = ++_generation;
    _session = null;
    ++_ownership;
    _cancelTimer?.call();
    _renewal = null;
    _view = AuthView(null, ++_revision);
    state = AsyncData(_view);
    final SignInOutcome outcome;
    try {
      outcome = await ref
          .read(authRepositoryProvider)
          .signIn(identifier, password);
    } on AppFailure catch (e, s) {
      if (generation != _generation || !ref.mounted) return const Superseded();
      if (e is StorageFailure) {
        _logoutPending = true;
        state = AsyncError(e, s);
      }
      rethrow;
    }
    if (generation != _generation || !ref.mounted) return const Superseded();
    if (outcome is Authenticated) {
      // Expired sign-in responses must not expose protected screens.
      if (!outcome.session.tokens.usable(ref.read(clockProvider).now())) {
        await logout();
        throw const UnauthorizedFailure();
      }
      _session = outcome.session;
      _view = AuthView(
        outcome.session.identity,
        _generation,
        ownership: _ownership,
      );
      state = AsyncData(_view);
      _schedule();
    }
    return outcome;
  }

  bool _due(AuthSession session) => !ref
      .read(clockProvider)
      .now()
      .isBefore(session.tokens.renewAt(ref.read(renewalLeadProvider)));

  @override
  Future<void> ensureFresh({bool force = false}) {
    if (!ref.mounted) return Future.error(const UnauthorizedFailure());
    if (_session case final AuthSession current) {
      if (!current.tokens.usable(ref.read(clockProvider).now())) {
        state = const AsyncLoading();
      }
    }
    final pending = _renewal;
    if (pending != null) return pending;
    final session = _session;
    if (session == null || _logoutPending) {
      return Future.error(const UnauthorizedFailure());
    }
    if (!force && !_due(session)) return Future.value();
    final generation = _generation;
    if (session.tokens.usable(ref.read(clockProvider).now())) {
      _view = AuthView(
        session.identity,
        _view.generation,
        notice: _view.notice,
        renewing: true,
        ownership: _ownership,
      );
      state = AsyncData(_view);
    }
    _cancelTimer?.call();
    final remaining = session.tokens.earliestExpiry.difference(
      ref.read(clockProvider).now(),
    );
    if (!remaining.isNegative && remaining != Duration.zero) {
      _cancelTimer = ref.read(clockProvider).schedule(remaining, () {
        if (ref.mounted && generation == _generation) {
          state = const AsyncLoading();
        }
      });
    }
    final operation = _refresh(session, generation);
    _renewal = operation;
    operation.then<void>(
      (_) {
        if (identical(_renewal, operation)) _renewal = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_renewal, operation)) _renewal = null;
      },
    );
    return operation;
  }

  Future<void> _refresh(AuthSession old, int generation) async {
    try {
      final outcome = await ref.read(authRepositoryProvider).refresh(old);
      if (generation != _generation || !ref.mounted) {
        throw const UnauthorizedFailure();
      }
      if (outcome is! Authenticated ||
          !outcome.session.tokens.usable(ref.read(clockProvider).now())) {
        await logout();
        if (ref.mounted && outcome is ActionRequired && !_logoutPending) {
          _view = AuthView(null, ++_revision, actionRequired: true);
          state = AsyncData(_view);
        }
        throw const UnauthorizedFailure();
      }
      _session = outcome.session;
      if (old.identity.userId != outcome.session.identity.userId ||
          old.identity.subject != outcome.session.identity.subject) {
        ++_generation;
        ++_ownership;
      }
      if (old.identity.role != outcome.session.identity.role) {
        ++_generation;
      }
      _view = AuthView(
        outcome.session.identity,
        ++_revision,
        ownership: _ownership,
      );
      state = AsyncData(_view);
      _schedule();
    } on AppFailure catch (e, s) {
      if (!ref.mounted || generation != _generation) rethrow;
      if (e is UnauthorizedFailure || e is ForbiddenFailure) {
        await logout();
      } else if (old.tokens.usable(ref.read(clockProvider).now())) {
        _view = AuthView(
          old.identity,
          _generation,
          notice: e,
          ownership: _ownership,
        );
        state = AsyncData(_view);
        // No immediate retry loop. Recheck exactly at expiry; resume/GET may retry.
        _cancelTimer?.call();
        _cancelTimer = ref.read(clockProvider).schedule(
          old.tokens.earliestExpiry.difference(ref.read(clockProvider).now()),
          () {
            if (ref.mounted && generation == _generation) {
              state = AsyncError(e, s);
            }
          },
        );
      } else {
        state = AsyncError(e, s);
      }
      rethrow;
    }
  }

  void _schedule() {
    _cancelTimer?.call();
    final session = _session;
    if (session == null) return;
    final delay = session.tokens
        .renewAt(ref.read(renewalLeadProvider))
        .difference(ref.read(clockProvider).now());
    _cancelTimer = ref
        .read(clockProvider)
        .schedule(
          delay.isNegative ? Duration.zero : delay,
          () => unawaited(resume()),
        );
  }

  Future<void> resume() async {
    if (_session == null || _logoutPending) return;
    try {
      await ensureFresh();
    } on AppFailure {
      // ensureFresh already publishes a safe, actionable state.
      return;
    }
  }

  @override
  Future<void> logout() async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    ++_ownership;
    _logoutPending = true;
    _session = null;
    _renewal = null;
    _cancelTimer?.call();
    _view = AuthView(null, ++_revision, locked: true);
    state = const AsyncLoading();
    try {
      await _clearSessionData();
      if (!ref.mounted || generation != _generation) return;
      _logoutPending = false;
      _view = AuthView(null, ++_revision);
      state = AsyncData(_view);
      ref.invalidate(loginControllerProvider);
    } on AppFailure catch (e, s) {
      if (ref.mounted && generation == _generation) state = AsyncError(e, s);
    }
  }

  /// Both durable stores must clear; a failure leaves auth locked for Retry.
  Future<void> _clearSessionData() async {
    // Start menu clear synchronously: queued writes lose ownership immediately.
    final menuClear = ref.read(menuCacheStoreProvider).clear();
    final sessionClear = ref.read(authRepositoryProvider).logout();
    await Future.wait([menuClear, sessionClear]);
    if (ref.mounted) ref.invalidate(menuRepositoryProvider);
  }
}
