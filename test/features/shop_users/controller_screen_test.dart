import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/localization/app_strings.dart';
import 'package:bookixo_pro/core/theme/app_theme.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/destination_scope_provider.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:bookixo_pro/features/shop_context/presentation/selected_shop_provider.dart';
import 'package:bookixo_pro/features/shop_users/domain/shop_user.dart';
import 'package:bookixo_pro/features/shop_users/domain/shop_users_repository.dart';
import 'package:bookixo_pro/features/shop_users/presentation/shop_users_controller.dart';
import 'package:bookixo_pro/features/shop_users/presentation/shop_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const directoryScope = (menu: MenuScope('account', null, 15), revision: 1);
final directoryScopeProvider =
    NotifierProvider<DirectoryScope, DestinationScope?>(DirectoryScope.new);

class DirectoryScope extends Notifier<DestinationScope?> {
  @override
  DestinationScope? build() => directoryScope;
  void replace(DestinationScope? scope) => state = scope;
}

ShopUsersPage sampleUsersPage(int shop, int page, {bool empty = false}) =>
    ShopUsersPage(
      users: empty
          ? []
          : [
              ShopUser(
                shopUserId: page + 1,
                shopId: shop,
                name: page == 0 ? null : 'Example staff',
                email: 'staff${page + 1}@example.test',
                phoneNumber: page == 0 ? null : '0000000000',
                role: 'SHOP_EMPLOYEE',
                active: page == 0 ? null : true,
              ),
            ],
      number: page,
      size: 20,
      totalElements: empty ? 0 : 21,
      totalPages: empty ? 0 : 2,
      last: empty || page == 1,
    );

class FakeShopUsersRepository implements ShopUsersRepository {
  final calls = <(MenuScope, int)>[];
  final gates = <(int, int), Completer<ShopUsersPage>>{};
  final failures = <int, AppFailure>{};
  bool empty = false;
  @override
  Future<ShopUsersPage> load(MenuScope scope, int page) async {
    calls.add((scope, page));
    if (failures[page] case final failure?) throw failure;
    return gates[(scope.shopId, page)]?.future ??
        sampleUsersPage(scope.shopId, page, empty: empty);
  }
}

void main() {
  late FakeShopUsersRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = FakeShopUsersRepository();
    container = ProviderContainer(
      overrides: [
        destinationScopeProvider('users-shop')
            .overrideWith((ref) => ref.watch(directoryScopeProvider)),
        shopUsersRepositoryProvider.overrideWithValue(repository),
        selectedShopProvider.overrideWithValue(const Shop(15, 'Example salon')),
      ],
    );
  });
  tearDown(() => container.dispose());
  ShopUsersView? view() =>
      container.read(shopUsersControllerProvider).asData?.value;
  ShopUsersController controller() =>
      container.read(shopUsersControllerProvider.notifier);
  void boot() => container.listen(shopUsersControllerProvider, (_, _) {});

  test(
    'single-flight load-more follows page metadata and stops at last',
    () async {
      boot();
      await container.read(shopUsersControllerProvider.future);
      final gate = Completer<ShopUsersPage>();
      repository.gates[(15, 1)] = gate;
      final pending = controller().loadMore();
      await controller().loadMore();
      expect(view()?.loadingMore, isTrue);
      expect(repository.calls.map((call) => call.$2), [0, 1]);
      gate.complete(sampleUsersPage(15, 1));
      await pending;
      expect(view()?.users.length, 2);
      await controller().loadMore();
      expect(repository.calls.length, 2);
    },
  );

  test(
    'load-more failure preserves rows and Retry requests the failed page',
    () async {
      boot();
      await container.read(shopUsersControllerProvider.future);
      repository.failures[1] = const NetworkFailure();
      await controller().loadMore();
      expect(view()?.users.length, 1);
      expect(view()?.moreFailure, isA<NetworkFailure>());
      repository.failures.clear();
      await controller().loadMore();
      expect(view()?.users.length, 2);
      expect(repository.calls.map((call) => call.$2), [0, 1, 1]);
    },
  );

  for (final replacement in [
    (menu: MenuScope('account', null, 16), revision: 2),
    (menu: MenuScope('another-account', null, 15), revision: 2),
    (menu: MenuScope('account', null, 15), revision: 3),
    null,
  ]) {
    test(
      'late pagination cannot publish across scope replacement $replacement',
      () async {
        boot();
        await container.read(shopUsersControllerProvider.future);
        final gate = Completer<ShopUsersPage>();
        repository.gates[(15, 1)] = gate;
        final pending = controller().loadMore();
        container.read(directoryScopeProvider.notifier).replace(replacement);
        await flush();
        gate.complete(sampleUsersPage(15, 1));
        await pending;
        await flush();
        expect(view()?.scope, replacement);
        expect(view()?.users.length, replacement == null ? null : 1);
      },
    );
  }

  test(
    'late initial response is discarded after A B A revision change',
    () async {
      final gate = Completer<ShopUsersPage>();
      repository.gates[(15, 0)] = gate;
      boot();
      await flush();
      repository.gates.clear();
      container.read(directoryScopeProvider.notifier).replace((
        menu: const MenuScope('account', null, 15),
        revision: 3,
      ));
      await flush();
      gate.complete(sampleUsersPage(15, 1));
      await flush();
      expect(view()?.page.number, 0);
      expect(view()?.scope.revision, 3);
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.forBrightness(brightness),
          home: const ShopUsersScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('loading, typed initial error, Retry and empty are explicit', (
    tester,
  ) async {
    final gate = Completer<ShopUsersPage>();
    repository.gates[(15, 0)] = gate;
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.completeError(const NetworkFailure(), StackTrace.current);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.network), findsOneWidget);
    repository.gates.clear();
    repository.empty = true;
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.shopUsersEmpty), findsOneWidget);
    expect(find.text(AppStrings.loadMore), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'read-only contacts, null fallbacks, pagination and large text $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(tester, brightness: brightness);
        await tester.pumpAndSettle();
        expect(find.text('staff1@example.test'), findsOneWidget);
        expect(find.text(AppStrings.phoneNotProvided), findsOneWidget);
        expect(find.text(AppStrings.userStatusUnknown), findsOneWidget);
        expect(find.text('SHOP_EMPLOYEE'), findsOneWidget);
        await tester.ensureVisible(find.text(AppStrings.loadMore));
        await tester.tap(find.text(AppStrings.loadMore));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Example staff'), 150);
        expect(find.text('staff2@example.test'), findsOneWidget);
        expect(find.text('0000000000'), findsOneWidget);
        expect(find.text(AppStrings.active), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
        expect(find.byIcon(Icons.delete), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
