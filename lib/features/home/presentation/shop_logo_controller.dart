import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/menu_controller.dart';
import '../../menu/presentation/scope_revision_provider.dart';
import '../../menu/domain/menu_snapshot.dart';
import '../../menu/presentation/menu_dependencies.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../data/logo_image_policy.dart';
import '../data/shop_logo_repository_impl.dart';
import '../domain/shop_logo.dart';
import '../domain/shop_logo_repository.dart';

final shopLogoRepositoryProvider = Provider<ShopLogoRepository>((ref) {
  if (ref.watch(configProvider).demo) return const _DemoLogoRepository();
  return ShopLogoRepositoryImpl(ref.watch(protectedClientProvider));
});

class _DemoLogoRepository implements ShopLogoRepository {
  const _DemoLogoRepository();
  @override
  Future<ShopLogo?> fetch(MenuScope scope) async => null;
}

final logoEvictProvider = Provider<void Function(ShopLogo)>(
  (ref) => LogoImagePolicy.evict,
);

/// Ownership changes at explicit login, not at access-token rotation.
final logoScopeProvider = Provider(
  (ref) => (
    scope: ref.watch(menuScopeProvider),
    ownership: ref.watch(
      authControllerProvider.select((auth) => auth.asData?.value.ownership),
    ),
  ),
);

final shopLogoControllerProvider =
    AsyncNotifierProvider<ShopLogoController, ShopLogo?>(
      ShopLogoController.new,
      isAutoDispose: true,
      retry: (_, _) => null,
    );

/// Memory-only, single-flight loads. Scope/epoch checks reject late responses.
class ShopLogoController extends AsyncNotifier<ShopLogo?> {
  int _epoch = 0;
  int _switchRevision = 0;
  Future<void>? _pending;
  ShopLogo? _owned;
  void Function()? _cancelExpiry;
  bool _imageRecoveryUsed = false;
  ({MenuScope? scope, int? ownership})? _scope;

  @override
  Future<ShopLogo?> build() async {
    _switchRevision = ref.watch(salonSwitchRevisionProvider);
    final scope = ref.watch(logoScopeProvider);
    _scope = scope;
    final epoch = ++_epoch;
    _pending = null;
    _imageRecoveryUsed = false;
    final evict = ref.read(logoEvictProvider);
    ref.onDispose(() {
      _cancelExpiry?.call();
      _cancelExpiry = null;
      final owned = _owned;
      _owned = null;
      if (owned != null) evict(owned);
    });
    if (scope.scope == null) return null;
    final operation = _fetch(epoch);
    final flight = operation.then<void>((_) {});
    _track(flight);
    return operation;
  }

  bool _current(int epoch) =>
      ref.mounted &&
      epoch == _epoch &&
      ref.read(salonSwitchRevisionProvider) == _switchRevision &&
      ref.read(logoScopeProvider) == _scope;

  void _clearImage() {
    _cancelExpiry?.call();
    _cancelExpiry = null;
    final old = _owned;
    _owned = null;
    if (old != null) ref.read(logoEvictProvider)(old);
  }

  Future<ShopLogo?> _fetch(int epoch) async {
    final scope = ref.read(logoScopeProvider).scope;
    if (scope == null) return null;
    try {
      final logo = await ref.read(shopLogoRepositoryProvider).fetch(scope);
      if (!_current(epoch)) return null;
      _owned = logo;
      final expiry = logo?.expiresAt;
      final clock = ref.read(clockProvider);
      if (expiry != null && expiry.isAfter(clock.now())) {
        _cancelExpiry = clock.schedule(expiry.difference(clock.now()), () {
          if (_current(epoch)) refresh();
        });
      }
      return logo;
    } on AppFailure catch (error, stack) {
      if (!_current(epoch)) return null;
      ref.read(appLoggerProvider).logoFailure(image: false);
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _track(Future<void> operation) {
    _pending = operation;
    operation.then<void>(
      (_) {
        if (_current(_epoch) && identical(_pending, operation)) _pending = null;
      },
      onError: (Object _, StackTrace _) {
        // The original future exposes the typed failure through AsyncValue.
        if (ref.mounted && identical(_pending, operation)) _pending = null;
      },
    );
  }

  /// Manual refresh and each foreground entry refetch; no guessed S3 lifetime.
  Future<void> refresh({bool imageRecovery = false}) {
    if (ref.read(logoScopeProvider).scope == null) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    if (!imageRecovery) _imageRecoveryUsed = false;
    _clearImage();
    state = const AsyncLoading();
    final epoch = _epoch;
    final operation = _refresh(epoch);
    _track(operation);
    return operation;
  }

  Future<void> _refresh(int epoch) async {
    try {
      final logo = await _fetch(epoch);
      if (_current(epoch)) state = AsyncData(logo);
    } on AppFailure catch (error, stack) {
      if (_current(epoch)) state = AsyncError(error, stack);
    }
  }

  /// One API retry for an expired/403 image per explicit refresh chain.
  Future<void> imageFailed(
    ShopLogo logo,
    Object error,
    StackTrace? stack,
  ) async {
    if (!_current(_epoch) || !identical(_owned, logo)) return;
    ref.read(appLoggerProvider).logoFailure(image: true);
    final recover =
        !_imageRecoveryUsed &&
        LogoImagePolicy.mayHaveExpired(
          logo,
          error,
          ref.read(clockProvider).now(),
        );
    _clearImage();
    state = const AsyncError(LogoImageFailure(), StackTrace.empty);
    if (recover) {
      _imageRecoveryUsed = true;
      await refresh(imageRecovery: true);
    }
  }
}
