import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../shop_context/presentation/selected_shop_provider.dart';
import '../domain/menu_snapshot.dart';
import '../domain/menu_repository.dart';
import 'menu_dependencies.dart';
import 'menu_projection.dart';
import 'scope_revision_provider.dart';

/// Background refresh retains a usable snapshot; boot uses AsyncValue gates.
class MenuView {
  const MenuView(
    this.snapshot, {
    this.refreshing = false,
    this.stale = false,
    this.notice,
  });
  final MenuSnapshot snapshot;
  final bool refreshing;
  final bool stale;
  final AppFailure? notice;
  MenuProjection get projection => MenuProjection(
    snapshot.keys,
    shopSetupChildren: snapshot.shopSetupChildren,
  );
}

final menuScopeProvider = Provider<MenuScope?>((ref) {
  final auth = ref.watch(
    authControllerProvider.select(
      (value) => (
        blocked:
            value.isLoading ||
            value.hasError ||
            value.asData?.value.locked == true,
        userId: value.asData?.value.identity?.userId,
        subject: value.asData?.value.identity?.subject,
        role: value.asData?.value.identity?.role,
        ownership: value.asData?.value.ownership,
      ),
    ),
  );
  final shop = ref.watch(selectedShopProvider);
  final user = auth.userId;
  if (auth.blocked ||
      user == null ||
      user.isEmpty ||
      shop == null ||
      !RolePolicy.supports(auth.role ?? AppRole.unknown)) {
    return null;
  }
  return MenuScope(user, auth.subject, shop.id);
});

final menuControllerProvider = AsyncNotifierProvider<MenuController, MenuView?>(
  MenuController.new,
  retry: (_, _) => null,
);

/// Trigger-based, single-flight refresh with stable scoped ownership.
class MenuController extends AsyncNotifier<MenuView?> {
  int _epoch = 0;
  int _switchRevision = 0;
  Future<void>? _pending;
  DateTime? _resumeAttempt;
  MenuScope? _deniedScope;
  @override
  Future<MenuView?> build() async {
    _switchRevision = ref.watch(salonSwitchRevisionProvider);
    final scope = ref.watch(menuScopeProvider);
    // A new explicit login may have the same user/shop but different ownership.
    ref.watch(
      authControllerProvider.select((auth) => auth.asData?.value.ownership),
    );
    final epoch = ++_epoch;
    _pending = null;
    _resumeAttempt = null;
    if (scope == null) return null;
    final repository = ref.read(menuRepositoryProvider);
    final operation = _load(scope, epoch, repository);
    final flight = operation.then<void>((_) {});
    _pending = flight;
    flight.then<void>(
      (_) {
        if (identical(_pending, flight)) _pending = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_pending, flight)) _pending = null;
      },
    );
    try {
      final result = await operation;
      if (_current(scope, epoch)) state = AsyncData(result);
      return result;
    } finally {
      if (identical(_pending, flight)) _pending = null;
    }
  }

  bool _current(MenuScope scope, int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(salonSwitchRevisionProvider) == _switchRevision &&
      ref.read(menuScopeProvider) == scope;

  Future<MenuView?> _load(
    MenuScope scope,
    int epoch,
    MenuRepository repository,
  ) async {
    MenuSnapshot? cached;
    AppFailure? cacheFailure;
    try {
      cached = await repository.read(scope);
    } on AppFailure catch (e, s) {
      if (!_current(scope, epoch)) return null;
      cacheFailure = e;
      ref.read(appLoggerProvider).menuFailure(s);
    }
    if (!_current(scope, epoch)) return null;
    return _fetch(scope, epoch, repository, cached, cacheFailure);
  }

  Future<MenuView?> _fetch(
    MenuScope scope,
    int epoch,
    MenuRepository repository,
    MenuSnapshot? fallback, [
    AppFailure? cacheFailure,
  ]) async {
    final MenuSnapshot fresh;
    try {
      fresh = await repository.fetch(scope);
    } on AppFailure catch (e, s) {
      if (!_current(scope, epoch)) return null;
      ref.read(appLoggerProvider).menuFailure(s);
      if (e is ForbiddenFailure) {
        _deniedScope = scope;
        state = AsyncError(e, s);
        try {
          await repository.clear();
        } on AppFailure catch (_, clearStack) {
          ref.read(appLoggerProvider).menuFailure(clearStack);
        }
      }
      final recoverable =
          e is NetworkFailure || e is ServerFailure || e is ContractFailure;
      if (!recoverable || _deniedScope == scope || fallback == null) {
        Error.throwWithStackTrace(e, s);
      }
      return MenuView(fallback, stale: true, notice: e);
    }
    if (!_current(scope, epoch)) return null;
    _deniedScope = null;
    // Publish revocations BEFORE IO. Storage failure must not restore old keys.
    state = AsyncData(MenuView(fresh, refreshing: true));
    try {
      await repository.write(fresh, () => _current(scope, epoch));
    } on AppFailure catch (e, s) {
      if (!_current(scope, epoch)) return null;
      ref.read(appLoggerProvider).menuFailure(s);
      return MenuView(fresh, notice: e);
    }
    return _current(scope, epoch)
        ? MenuView(fresh, notice: cacheFailure)
        : null;
  }

  Future<void> refresh({bool resume = false}) {
    final scope = ref.read(menuScopeProvider);
    if (scope == null) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    final now = ref.read(clockProvider).now();
    final old = state.asData?.value;
    if (resume) {
      if (old != null && !old.snapshot.needsRefresh(now)) return Future.value();
      final attempt = _resumeAttempt;
      if (attempt != null &&
          now.difference(attempt) < MenuSnapshot.refreshInterval) {
        return Future.value();
      }
      _resumeAttempt = now;
    }
    final epoch = _epoch;
    state = old == null
        ? const AsyncLoading()
        : AsyncData(
            MenuView(
              old.snapshot,
              refreshing: true,
              stale: old.stale,
              notice: old.notice,
            ),
          );
    final operation = _refresh(scope, epoch, old?.snapshot);
    _pending = operation;
    operation.then<void>(
      (_) {
        if (identical(_pending, operation)) _pending = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_pending, operation)) _pending = null;
      },
    );
    return operation;
  }

  Future<void> _refresh(
    MenuScope scope,
    int epoch,
    MenuSnapshot? fallback,
  ) async {
    try {
      final repository = ref.read(menuRepositoryProvider);
      final result = fallback == null
          ? await _load(scope, epoch, repository)
          : await _fetch(scope, epoch, repository, fallback);
      if (_current(scope, epoch)) state = AsyncData(result);
    } on AppFailure catch (e, s) {
      if (_current(scope, epoch)) state = AsyncError(e, s);
    }
  }
}
