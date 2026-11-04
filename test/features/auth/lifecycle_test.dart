import 'dart:async';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/auth/domain/auth_models.dart';
import 'package:bookixo_pro/features/auth/domain/role_policy.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:bookixo_pro/features/auth/presentation/login_controller.dart';
import 'package:bookixo_pro/features/menu/data/menu_cache_store.dart';
import 'package:bookixo_pro/features/menu/presentation/menu_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthRepository repository;
  late FakeClock clock;
  late ProviderContainer container;
  setUp(() {
    repository = FakeAuthRepository();
    clock = FakeClock();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
        menuCacheStoreProvider.overrideWithValue(
          MenuCacheStore(MemoryBackend()),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<AuthController> start() async {
    await container.read(authControllerProvider.future);
    return container.read(authControllerProvider.notifier);
  }

  test('startup signed out with no credentials', () async {
    await start();
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test(
    'startup waits for near-expiry renewal and derives fresh role',
    () async {
      repository.restored = sampleSession(
        at: testNow.subtract(const Duration(minutes: 59)),
      );
      repository.refreshResult = Authenticated(
        sampleSession(groups: ['shop_employee']),
      );
      await start();
      expect(repository.renewals, 1);
      expect(
        container.read(authControllerProvider).requireValue.identity?.role,
        AppRole.employee,
      );
    },
  );
  test('expired access or ID never publishes stale startup claims', () async {
    repository.restored = sampleSession(
      at: testNow.subtract(const Duration(hours: 2)),
    );
    repository.refreshGate = Completer();
    final startup = container.read(authControllerProvider.future);
    await flush();
    expect(container.read(authControllerProvider).isLoading, isTrue);
    repository.refreshGate?.complete(Authenticated(sampleSession()));
    await startup;
    expect(repository.renewals, 1);
  });
  test('restore failure blocks instead of silently signing out', () async {
    repository.restoreFailure = const StorageFailure();
    await expectLater(
      container.read(authControllerProvider.future),
      throwsA(isA<StorageFailure>()),
    );
    expect(container.read(authControllerProvider).hasError, isTrue);
  });
  test(
    'expired renewal response during startup never opens protected screens',
    () async {
      repository.restored = sampleSession(
        at: testNow.subtract(const Duration(hours: 2)),
      );
      repository.refreshResult = Authenticated(
        sampleSession(at: testNow.subtract(const Duration(hours: 2))),
      );
      await start();
      expect(
        container.read(authControllerProvider).requireValue.identity,
        isNull,
      );
      expect(repository.logouts, 1);
    },
  );
  test(
    'expiry during slow proactive refresh blocks display until recovery',
    () async {
      repository.restored = sampleSession(lifetime: 10);
      repository.refreshGate = Completer();
      await start();
      clock.advance(const Duration(seconds: 8));
      await repository.refreshStarted.future;
      clock.advance(const Duration(seconds: 2));
      expect(container.read(authControllerProvider).isLoading, isTrue);
      repository.refreshGate?.complete(
        Authenticated(sampleSession(at: clock.now())),
      );
      await flush();
      expect(
        container.read(authControllerProvider).asData?.value.identity,
        isNotNull,
      );
    },
  );
  test(
    'resume after expiry gates protected display while renewal is pending',
    () async {
      repository.restored = sampleSession(lifetime: 10);
      repository.refreshGate = Completer();
      final controller = await start();
      // Background may suspend timers completely.
      clock.time = testNow.add(const Duration(seconds: 12));
      final resumed = controller.resume();
      expect(container.read(authControllerProvider).isLoading, isTrue);
      repository.refreshGate?.complete(
        Authenticated(sampleSession(at: clock.now())),
      );
      await resumed;
      expect(
        container.read(authControllerProvider).asData?.value.identity,
        isNotNull,
      );
    },
  );
  test(
    'short lifetime schedules bounded lead, not tight renewal loop',
    () async {
      repository.restored = sampleSession(lifetime: 10);
      await start();
      expect(
        clock.scheduled.single.at,
        testNow.add(const Duration(seconds: 8)),
      );
    },
  );
  test('timer/resume/request renewal share a single flight', () async {
    repository.restored = sampleSession();
    repository.refreshGate = Completer();
    final controller = await start();
    clock.advance(const Duration(minutes: 59));
    final request = controller.ensureFresh();
    final resume = controller.resume();
    await flush();
    expect(repository.renewals, 1);
    repository.refreshGate?.complete(
      Authenticated(sampleSession(at: clock.now())),
    );
    await Future.wait([request, resume]);
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNotNull,
    );
  });
  test(
    'proactive transient failure retains valid session then blocks at expiry',
    () async {
      repository.restored = sampleSession(lifetime: 10);
      final controller = await start();
      repository.refreshFailure = const NetworkFailure();
      clock.advance(const Duration(seconds: 8));
      await controller.resume();
      expect(
        container.read(authControllerProvider).asData?.value.notice,
        isA<NetworkFailure>(),
      );
      expect(repository.logouts, 0);
      clock.advance(const Duration(seconds: 2));
      expect(container.read(authControllerProvider).hasError, isTrue);
      repository.refreshFailure = null;
      repository.refreshResult = Authenticated(sampleSession(at: clock.now()));
      await controller.retry();
      expect(container.read(authControllerProvider).hasError, isFalse);
    },
  );
  test('revoked refresh logs out and cancels timer', () async {
    repository.restored = sampleSession();
    final controller = await start();
    repository.refreshFailure = const UnauthorizedFailure();
    await expectLater(
      controller.ensureFresh(force: true),
      throwsA(isA<UnauthorizedFailure>()),
    );
    expect(repository.logouts, 1);
    expect(controller.currentSession, isNull);
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test('logout during refresh does not publish old identity', () async {
    repository.restored = sampleSession();
    repository.refreshGate = Completer();
    final controller = await start();
    final refresh = controller.ensureFresh(force: true);
    final assertion = expectLater(refresh, throwsA(isA<UnauthorizedFailure>()));
    await controller.logout();
    repository.refreshGate?.complete(Authenticated(sampleSession()));
    await assertion;
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test('logout during sign-in suppresses stale session', () async {
    final controller = await start();
    repository.signInGate = Completer();
    final signIn = controller.signIn('owner@example.test', 'test');
    await controller.logout();
    repository.signInGate?.complete(Authenticated(sampleSession()));
    expect(await signIn, isA<Superseded>());
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test('secure deletion failure remains locked; Retry clears', () async {
    repository.restored = sampleSession();
    final controller = await start();
    repository.logoutFailure = const StorageFailure();
    await controller.logout();
    expect(container.read(authControllerProvider).hasError, isTrue);
    expect(controller.currentSession, isNull);
    repository.logoutFailure = null;
    await controller.retry();
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test('login validation and duplicate submits; trims email only', () async {
    await start();
    final login = container.read(loginControllerProvider.notifier);
    await login.submit('bad', '');
    expect(repository.signs, 0);
    expect(
      container.read(loginControllerProvider).requireValue.identifierError,
      isNotNull,
    );
    repository.signInGate = Completer();
    final first = login.submit(' owner@example.test ', ' test ');
    await login.submit('employee@example.test', 'duplicate');
    expect(repository.signs, 1);
    expect(repository.submittedIdentifier, 'owner@example.test');
    expect(repository.submittedPassword, ' test ');
    repository.signInGate?.complete(const ActionRequired());
    await first;
    expect(
      container.read(loginControllerProvider).requireValue.message,
      isNotNull,
    );
  });
  test(
    'invalid credentials become async feedback without clearing form state',
    () async {
      await start();
      repository.signInFailure = const UnauthorizedFailure();
      await container
          .read(loginControllerProvider.notifier)
          .submit('owner@example.test', 'test');
      expect(
        container.read(loginControllerProvider).error,
        isA<UnauthorizedFailure>(),
      );
    },
  );
  test('refresh challenge returns friendly signed-out feedback', () async {
    repository.restored = sampleSession();
    repository.refreshResult = const ActionRequired();
    final controller = await start();
    await expectLater(
      controller.ensureFresh(force: true),
      throwsA(isA<UnauthorizedFailure>()),
    );
    expect(
      container.read(authControllerProvider).requireValue.actionRequired,
      isTrue,
    );
    expect(controller.currentSession, isNull);
  });
  test(
    'startup challenge never authenticates or retains credentials',
    () async {
      repository.restored = sampleSession(
        at: testNow.subtract(const Duration(hours: 2)),
      );
      repository.refreshResult = const ActionRequired();
      await start();
      expect(
        container.read(authControllerProvider).requireValue.actionRequired,
        isTrue,
      );
      expect(repository.logouts, 1);
    },
  );
  test('failed account replacement secure clear remains locked', () async {
    final controller = await start();
    repository.signInFailure = const StorageFailure();
    await expectLater(
      controller.signIn('owner@example.test', 'test'),
      throwsA(isA<StorageFailure>()),
    );
    expect(container.read(authControllerProvider).hasError, isTrue);
    await expectLater(
      controller.signIn('owner@example.test', 'test'),
      throwsA(isA<StorageFailure>()),
    );
    await controller.retry();
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test(
    'stale startup renewal failure cannot clear a replacement account',
    () async {
      repository.restored = sampleSession(
        at: testNow.subtract(const Duration(hours: 2)),
      );
      repository.refreshGate = Completer();
      final startup = container.read(authControllerProvider.future);
      await repository.refreshStarted.future;
      final controller = container.read(authControllerProvider.notifier);
      repository.signInResult = Authenticated(
        sampleSession(userId: 'replacement'),
      );
      await controller.signIn('new@example.test', 'test');
      repository.refreshGate?.completeError(
        const UnauthorizedFailure(),
        StackTrace.empty,
      );
      await startup;
      expect(
        container.read(authControllerProvider).requireValue.identity?.userId,
        'replacement',
      );
      expect(repository.logouts, 0);
    },
  );
  test('stale startup read failure cannot override logout state', () async {
    repository.restoreGate = Completer();
    final startup = container.read(authControllerProvider.future);
    await flush();
    final controller = container.read(authControllerProvider.notifier);
    await controller.logout();
    repository.restoreGate?.completeError(
      const StorageFailure(),
      StackTrace.empty,
    );
    await startup;
    expect(container.read(authControllerProvider).hasError, isFalse);
    expect(
      container.read(authControllerProvider).requireValue.identity,
      isNull,
    );
  });
  test(
    'role removal on refresh invalidates previous display permission',
    () async {
      repository.restored = sampleSession();
      repository.refreshResult = Authenticated(sampleSession(groups: []));
      final controller = await start();
      final oldGeneration = controller.generation;
      await controller.ensureFresh(force: true);
      expect(controller.generation, greaterThan(oldGeneration));
      expect(
        container.read(authControllerProvider).requireValue.identity?.role,
        AppRole.unknown,
      );
    },
  );
}
