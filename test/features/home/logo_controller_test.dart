import 'dart:async';

import 'package:bookixo_pro/core/config/app_config.dart';
import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/core/logging/app_logger.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/home/domain/shop_logo.dart';
import 'package:bookixo_pro/features/home/domain/shop_logo_repository.dart';
import 'package:bookixo_pro/features/home/presentation/shop_logo_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/domain/menu_snapshot.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:bookixo_pro/features/menu/presentation/scope_revision_provider.dart';
import 'package:bookixo_pro/features/shop_context/presentation/shop_context_controller.dart';
import 'package:bookixo_pro/features/shop_context/domain/shop_context.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class FakeLogoRepository implements ShopLogoRepository {
  ShopLogo? result;
  AppFailure? failure;
  Completer<ShopLogo?>? gate;
  final List<MenuScope> calls = [];
  @override
  Future<ShopLogo?> fetch(MenuScope scope) async {
    calls.add(scope);
    if (failure case final AppFailure error) throw error;
    return gate == null ? result : gate?.future;
  }
}

class LogoLogger extends AppLogger {
  final List<String> events = [];
  int tileTaps = 0;
  int buttonTaps = 0;
  @override
  void upsellTile() => tileTaps++;
  @override
  void upsellButton() => buttonTaps++;
  @override
  void logoFailure({required bool image}) =>
      events.add(image ? 'image' : 'api');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late FakeAuthRepository auth;
  late FakeLogoRepository logos;
  late FakeClock clock;
  late LogoLogger logger;
  late List<ShopLogo> evicted;
  setUp(() {
    auth = FakeAuthRepository()..restored = sampleSession();
    logos = FakeLogoRepository();
    clock = FakeClock();
    logger = LogoLogger();
    evicted = [];
    container = ProviderContainer(
      overrides: [
        configProvider.overrideWithValue(
          AppConfig.parse('https://example.test', debug: true, demo: true),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        shopRepositoryProvider.overrideWithValue(
          FakeShopRepository()
            ..result = ShopContext(const [
              Shop(15, 'First'),
              Shop(16, 'Second'),
            ], 15),
        ),
        clockProvider.overrideWithValue(clock),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
        shopLogoRepositoryProvider.overrideWithValue(logos),
        logoEvictProvider.overrideWithValue(evicted.add),
        appLoggerProvider.overrideWithValue(logger),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> boot() async {
    await container.read(authControllerProvider.future);
    await container.read(shopContextProvider.future);
    await flush();
    container.listen(shopLogoControllerProvider, (_, _) {});
    await container.read(shopLogoControllerProvider.future);
  }

  ShopLogo logo(String id, {DateTime? expiry}) => ShopLogo(
    Uri.parse('https://images.example.test/$id?synthetic=fixture'),
    expiresAt: expiry,
  );
  test('rapid A B A switch rejects late logo and keeps new artwork', () async {
    await boot();
    final gate = Completer<ShopLogo?>();
    logos.gate = gate;
    final pending = container
        .read(shopLogoControllerProvider.notifier)
        .refresh();
    await flush();
    logos.gate = null;
    logos.result = logo('current');
    final selection = container.read(demoShopSelectionProvider.notifier);
    selection.select(16);
    selection.select(15);
    await flush();
    gate.complete(logo('old'));
    await pending;
    await flush();
    expect(container.read(salonSwitchRevisionProvider), 2);
    expect(
      container.read(shopLogoControllerProvider).asData?.value?.url.path,
      '/current',
    );
  });
  test(
    'absence, manual and foreground refresh are independent of menu 60s',
    () async {
      await boot();
      expect(container.read(shopLogoControllerProvider).asData?.value, isNull);
      final controller = container.read(shopLogoControllerProvider.notifier);
      await controller.refresh();
      await controller.refresh();
      expect(logos.calls.length, 3);
      logos.gate = Completer();
      final a = controller.refresh();
      final b = controller.refresh();
      expect(identical(a, b), isTrue);
      logos.gate?.complete(logo('fresh'));
      await a;
      expect(
        container.read(shopLogoControllerProvider).asData?.value?.url.path,
        '/fresh',
      );
    },
  );
  test('API forbidden is visible typed error, not no-logo', () async {
    await boot();
    logos.failure = const ForbiddenFailure();
    await container.read(shopLogoControllerProvider.notifier).refresh();
    expect(
      container.read(shopLogoControllerProvider).error,
      isA<ForbiddenFailure>(),
    );
    expect(logger.events, ['api']);
  });
  test(
    'expiry metadata schedules refresh and does not use 900 or 60',
    () async {
      logos.result = logo(
        'expiring',
        expiry: testNow.add(const Duration(seconds: 120)),
      );
      await boot();
      clock.advance(const Duration(seconds: 60));
      await flush();
      expect(logos.calls.length, 1);
      logos.result = logo('new');
      clock.advance(const Duration(seconds: 60));
      await flush();
      expect(logos.calls.length, 2);
      expect(evicted, hasLength(1));
    },
  );
  test(
    'expired image API retry once; second failure keeps sanitized error',
    () async {
      final old = logo(
        'old',
        expiry: testNow.subtract(const Duration(seconds: 1)),
      );
      logos.result = old;
      await boot();
      final controller = container.read(shopLogoControllerProvider.notifier);
      await controller.imageFailed(
        old,
        NetworkImageLoadException(statusCode: 403, uri: old.url),
        StackTrace.empty,
      );
      expect(logos.calls.length, 2);
      await controller.imageFailed(
        old,
        NetworkImageLoadException(statusCode: 403, uri: old.url),
        StackTrace.empty,
      );
      expect(logos.calls.length, 2);
      expect(
        container.read(shopLogoControllerProvider).error,
        isA<LogoImageFailure>(),
      );
      expect(logger.events, ['image', 'image']);
      expect(
        container.read(shopLogoControllerProvider).error.toString(),
        isNot(contains('synthetic')),
      );
    },
  );
  test('decode failure has feedback but no pointless API retry', () async {
    final current = logo('decode');
    logos.result = current;
    await boot();
    await container
        .read(shopLogoControllerProvider.notifier)
        .imageFailed(
          current,
          StateError('synthetic secret URL must not be logged'),
          StackTrace.empty,
        );
    expect(logos.calls.length, 1);
    expect(logger.events, ['image']);
    expect(
      container.read(shopLogoControllerProvider).error,
      isA<LogoImageFailure>(),
    );
  });
  test('token renewal does not reload stable logo scope', () async {
    logos.result = logo('same');
    await boot();
    await container
        .read(authControllerProvider.notifier)
        .ensureFresh(force: true);
    await flush();
    expect(logos.calls.length, 1);
    expect(evicted, isEmpty);
  });
  test('a new explicit login for the same account refreshes artwork', () async {
    logos.result = logo('same-account-old');
    await boot();
    logos.result = logo('same-account-new');
    await container
        .read(authControllerProvider.notifier)
        .signIn('synthetic@example.test', 'synthetic');
    await flush();
    expect(logos.calls, hasLength(2));
    expect(
      container.read(shopLogoControllerProvider).asData?.value?.url.path,
      '/same-account-new',
    );
    expect(evicted.map((e) => e.url.path), ['/same-account-old']);
  });
  test('logout evicts only owned logo and discards in-flight result', () async {
    logos.result = logo('old');
    await boot();
    logos.gate = Completer();
    final refresh = container
        .read(shopLogoControllerProvider.notifier)
        .refresh();
    await container.read(authControllerProvider.notifier).logout();
    await flush();
    logos.gate?.complete(logo('late'));
    await refresh;
    await flush();
    expect(container.read(shopLogoControllerProvider).asData?.value, isNull);
    expect(evicted.map((e) => e.url.path), ['/old']);
  });
  test('account replacement discards old request with no logo flash', () async {
    await boot();
    logos.gate = Completer();
    final old = container.read(shopLogoControllerProvider.notifier).refresh();
    final gate = logos.gate;
    logos.gate = null;
    logos.result = logo('account-two');
    auth.signInResult = Authenticated(sampleSession(userId: '6'));
    await container
        .read(authControllerProvider.notifier)
        .signIn('synthetic@example.test', 'synthetic');
    await flush();
    gate?.complete(logo('account-one-late'));
    await old;
    await flush();
    expect(
      container.read(shopLogoControllerProvider).asData?.value?.url.path,
      '/account-two',
    );
    expect(logos.calls.last.userId, '6');
  });
  test('validated shop replacement discards in-flight old shop', () async {
    await boot();
    logos.gate = Completer();
    final old = container.read(shopLogoControllerProvider.notifier).refresh();
    final gate = logos.gate;
    logos.gate = null;
    logos.result = logo('shop-two');
    container.read(demoShopSelectionProvider.notifier).select(16);
    await flush();
    gate?.complete(logo('shop-one-late'));
    await old;
    await flush();
    expect(logos.calls.last.shopId, 16);
    expect(
      container.read(shopLogoControllerProvider).asData?.value?.url.path,
      '/shop-two',
    );
  });
}
