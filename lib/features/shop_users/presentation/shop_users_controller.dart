import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/auth_dependencies.dart';
import '../../menu/presentation/destination_scope_provider.dart';
import '../../shop_context/presentation/shop_context_controller.dart';
import '../data/mock_shop_users_repository.dart';
import '../data/shop_users_repository_impl.dart';
import '../domain/shop_user.dart';
import '../domain/shop_users_repository.dart';

final shopUsersRepositoryProvider = Provider<ShopUsersRepository>(
  (ref) => ref.watch(configProvider).demo
      ? const MockShopUsersRepository()
      : ShopUsersRepositoryImpl(ref.watch(protectedClientProvider)),
);

class ShopUsersView {
  ShopUsersView({
    required this.scope,
    required List<ShopUser> users,
    required this.page,
    this.loadingMore = false,
    this.moreFailure,
    this.moreFailureStack,
  }) : users = List.unmodifiable(users);
  final DestinationScope scope;
  final List<ShopUser> users;
  final ShopUsersPage page;
  final bool loadingMore;
  final AppFailure? moreFailure;
  final StackTrace? moreFailureStack;

  ShopUsersView pending({
    bool loading = false,
    AppFailure? failure,
    StackTrace? stack,
  }) => ShopUsersView(
    scope: scope,
    users: users,
    page: page,
    loadingMore: loading,
    moreFailure: failure,
    moreFailureStack: stack,
  );
}

final shopUsersControllerProvider =
    AsyncNotifierProvider<ShopUsersController, ShopUsersView?>(
      ShopUsersController.new,
      isAutoDispose: true,
      retry: (_, _) => null,
    );

/// Single-flight pagination; superseded account/shop/permission reads never land.
class ShopUsersController extends AsyncNotifier<ShopUsersView?> {
  int _epoch = 0;
  DestinationScope? _scope;

  @override
  Future<ShopUsersView?> build() async {
    final epoch = ++_epoch;
    final scope = ref.watch(destinationScopeProvider('users-shop'));
    _scope = scope;
    if (scope == null) return null;
    final repository = ref.watch(shopUsersRepositoryProvider);
    final page = await repository.load(scope.menu, 0);
    return _current(epoch, scope)
        ? ShopUsersView(scope: scope, users: page.users, page: page)
        : null;
  }

  bool _current(int epoch, DestinationScope scope) =>
      ref.mounted &&
      epoch == _epoch &&
      _scope == scope &&
      ref.read(destinationScopeProvider('users-shop')) == scope;

  void refresh() => ref.invalidateSelf();

  Future<void> loadMore() async {
    final view = state.asData?.value;
    if (state.isLoading ||
        view == null ||
        view.loadingMore ||
        !view.page.hasNext ||
        !_current(_epoch, view.scope)) {
      return;
    }
    final epoch = _epoch;
    final scope = view.scope;
    final repository = ref.read(shopUsersRepositoryProvider);
    state = AsyncData(view.pending(loading: true));
    try {
      final page = await repository.load(scope.menu, view.page.number + 1);
      if (!_current(epoch, scope)) return;
      // Stable identities prevent duplicate rows when directory pages shift.
      final merged = {for (final user in view.users) user.shopUserId: user};
      for (final user in page.users) {
        merged[user.shopUserId] = user;
      }
      state = AsyncData(
        ShopUsersView(scope: scope, users: merged.values.toList(), page: page),
      );
    } on AppFailure catch (failure, stack) {
      if (_current(epoch, scope)) {
        state = AsyncData(view.pending(failure: failure, stack: stack));
      }
    }
  }
}
