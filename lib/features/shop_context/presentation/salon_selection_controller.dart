import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/domain/role_policy.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../data/salon_preference_repository_impl.dart';
import '../domain/salon_preference_repository.dart';
import 'salon_switch_guard.dart';
import 'shop_context_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';

final salonPreferenceRepositoryProvider = Provider<SalonPreferenceRepository>(
  (ref) => SalonPreferenceRepositoryImpl(
    const PlatformSalonPreferenceBackend(FlutterSecureStorage()),
  ),
);

class SalonSelection {
  const SalonSelection(
    this.id, {
    this.notice,
    this.restoring = false,
    this.revision = 0,
  });
  final int? id;
  final AppFailure? notice;
  final bool restoring;
  final int revision;
}

final salonSelectionProvider =
    NotifierProvider<SalonSelectionController, SalonSelection>(
      SalonSelectionController.new,
    );

/// Explicit login ownership and stable account identity, never token identity.
class SalonSelectionController extends Notifier<SalonSelection> {
  int _epoch = 0;
  int _switchRevision = 0;
  String? _account;
  int? _ownership;

  @override
  SalonSelection build() {
    final auth = ref.watch(
      authControllerProvider.select(
        (value) => (
          blocked:
              value.isLoading ||
              value.hasError ||
              value.asData?.value.locked == true,
          user: value.asData?.value.identity?.userId,
          subject: value.asData?.value.identity?.subject,
          role: value.asData?.value.identity?.role,
          ownership: value.asData?.value.ownership,
        ),
      ),
    );
    final context = ref.watch(shopContextProvider).asData?.value;
    final epoch = ++_epoch;
    _ownership = auth.ownership;
    _account = null;
    if (auth.blocked ||
        auth.user == null ||
        context == null ||
        context.shops.isEmpty) {
      return SalonSelection(null, revision: _switchRevision);
    }
    final primary = context.shops.length == 1
        ? context.shops.single.id
        : context.primaryShopId;
    if (auth.role != AppRole.owner) {
      return SalonSelection(primary, revision: _switchRevision);
    }
    if (ref.watch(configProvider).demo) {
      return SalonSelection(primary, revision: _switchRevision);
    }
    final account = jsonEncode([auth.user, auth.subject]);
    _account = account;
    if (context.shops.length == 1 && primary != null) {
      unawaited(
        Future<void>.microtask(() => _persist(account, epoch, primary)),
      );
      return SalonSelection(primary, revision: _switchRevision);
    }
    // Do not expose the primary while the last-used preference is loading.
    unawaited(Future<void>.microtask(() => _restore(account, epoch, primary)));
    return SalonSelection(null, restoring: true, revision: _switchRevision);
  }

  bool _current(String account, int epoch) {
    if (!ref.mounted || epoch != _epoch || account != _account) return false;
    final auth = ref.read(authControllerProvider).asData?.value;
    final identity = auth?.identity;
    return identity != null &&
        auth?.locked != true &&
        auth?.ownership == _ownership &&
        jsonEncode([identity.userId, identity.subject]) == account;
  }

  Future<void> _restore(String account, int epoch, int? primary) async {
    if (!_current(account, epoch)) return;
    int? saved;
    AppFailure? notice;
    try {
      saved = await ref.read(salonPreferenceRepositoryProvider).read(account);
    } on AppFailure catch (failure, stack) {
      if (ref.mounted) ref.read(appLoggerProvider).menuFailure(stack);
      notice = failure;
    }
    if (!_current(account, epoch)) return;
    final shops = ref.read(shopContextProvider).asData?.value?.shops ?? [];
    final selected = shops.any((shop) => shop.id == saved && shop.id > 0)
        ? saved
        : primary;
    state = SalonSelection(selected, notice: notice, revision: _switchRevision);
    if (notice == null && selected != null && saved != selected) {
      unawaited(_persist(account, epoch, selected));
    }
  }

  /// Revalidate after the confirmation await. Nonmembers and busy requests fail closed.
  bool select(int id, {bool discardConfirmed = false}) {
    final auth = ref.read(authControllerProvider).asData?.value;
    final guard = ref.read(salonSwitchGuardProvider);
    if (auth?.identity?.role != AppRole.owner ||
        auth?.locked == true ||
        state.restoring ||
        guard.busy ||
        (guard.dirty && !discardConfirmed)) {
      return false;
    }
    final shops = ref.read(shopContextProvider).asData?.value?.shops ?? [];
    if (id <= 0 || !shops.any((shop) => shop.id == id)) return false;
    if (state.id == id) return true;
    final epoch = ++_epoch;
    state = SalonSelection(id, revision: ++_switchRevision);
    ref.read(salonSwitchRevisionProvider.notifier).advance();
    final account = _account;
    if (account != null) unawaited(_persist(account, epoch, id));
    return true;
  }

  Future<void> _persist(String account, int epoch, int id) async {
    if (!_current(account, epoch)) return;
    try {
      await ref
          .read(salonPreferenceRepositoryProvider)
          .write(account, id, () => _current(account, epoch));
      if (_current(account, epoch) && state.notice != null) {
        state = SalonSelection(id, revision: _switchRevision);
      }
    } on AppFailure catch (failure, stack) {
      if (ref.mounted) ref.read(appLoggerProvider).menuFailure(stack);
      if (_current(account, epoch)) {
        state = SalonSelection(id, notice: failure, revision: _switchRevision);
      }
    }
  }

  void retryPreference() {
    final account = _account;
    final id = state.id;
    if (account != null && id != null) unawaited(_persist(account, _epoch, id));
  }
}
