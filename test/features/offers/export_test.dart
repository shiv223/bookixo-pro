import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:bookixo_pro/core/errors/app_failure.dart';
import 'package:bookixo_pro/features/offers/domain/voucher_export.dart';
import 'package:bookixo_pro/features/offers/presentation/offers_controller.dart';
import 'package:bookixo_pro/features/offers/presentation/voucher_export_controller.dart';
import 'package:bookixo_pro/features/auth/presentation/auth_dependencies.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import 'controller_test.dart';

class FakeVoucherPlatform implements VoucherPlatform {
  int permissions = 0;
  int saves = 0;
  int shares = 0;
  bool allowed = true;
  Completer<bool>? permissionGate;
  Completer<void>? shareGate;
  AppFailure? failure;
  @override
  Future<bool> requestSaveAccess() async {
    permissions++;
    return permissionGate?.future ?? allowed;
  }

  @override
  Future<void> save(Uint8List png) async {
    saves++;
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<void> share(Uint8List png, Rect origin) async {
    shares++;
    final error = failure;
    if (error != null) throw error;
    await shareGate?.future;
  }
}

class FakeVoucherCapture implements VoucherCapture {
  Completer<Uint8List>? gate;
  int calls = 0;
  @override
  final Rect origin = const Rect.fromLTWH(0, 0, 320, 190);
  @override
  Future<Uint8List> capture() async {
    calls++;
    return gate?.future ?? Uint8List.fromList([1, 2, 3]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rules reconciliation during capture rejects stale image', () async {
    final platform = FakeVoucherPlatform();
    final repo = FakeOffersRepository();
    final container = ProviderContainer(
      overrides: [
        offersScopeProvider.overrideWithValue(firstScope),
        offersRepositoryProvider.overrideWithValue(repo),
        voucherPlatformProvider.overrideWithValue(platform),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 10, 8))),
      ],
    );
    addTearDown(container.dispose);
    container.listen(offersControllerProvider, (_, _) {});
    container.listen(voucherExportControllerProvider, (_, _) {});
    await flush();
    final export = container.read(voucherExportControllerProvider.notifier);
    final capture = FakeVoucherCapture()..gate = Completer();
    final stale = export.export(1, 1, ExportAction.share, capture);
    final refresh = container
        .read(offersControllerProvider.notifier)
        .retry(OffersResource.rules, restart: true);
    final blocked = FakeVoucherCapture();
    await export.export(1, 1, ExportAction.save, blocked);
    expect(blocked.calls, 0);
    await refresh;
    capture.gate?.complete(Uint8List(1));
    await stale;
    expect(platform.shares, 0);
    expect(
      container.read(voucherExportControllerProvider)[1]?.failure,
      isA<ExportFailure>(),
    );
    repo.rulesFailure = const NetworkFailure();
    await container
        .read(offersControllerProvider.notifier)
        .retry(OffersResource.rules, restart: true);
    await export.export(1, 1, ExportAction.save, blocked);
    expect(blocked.calls, 0);
    expect(platform.permissions, 0);
  });
  test(
    'share never requests permission; save requests only on explicit Save',
    () async {
      final platform = FakeVoucherPlatform();
      final service = VoucherExportService(platform);
      final capture = FakeVoucherCapture();
      await service.export(ExportAction.share, capture, () => true);
      expect(platform.permissions, 0);
      expect(platform.shares, 1);
      await service.export(ExportAction.save, capture, () => true);
      expect(platform.permissions, 1);
      expect(platform.saves, 1);
      platform.allowed = false;
      await expectLater(
        service.export(ExportAction.save, capture, () => true),
        throwsA(
          isA<ExportFailure>().having(
            (e) => e.kind,
            'kind',
            ExportFailureKind.denied,
          ),
        ),
      );
      expect(platform.saves, 1);
    },
  );
  test(
    'scope/status change during capture or permission prevents disclosure/save',
    () async {
      final platform = FakeVoucherPlatform();
      final service = VoucherExportService(platform);
      final capture = FakeVoucherCapture()..gate = Completer();
      var current = true;
      final share = service.export(ExportAction.share, capture, () => current);
      current = false;
      capture.gate?.complete(Uint8List(1));
      await expectLater(share, throwsA(isA<ExportFailure>()));
      expect(platform.shares, 0);
      current = true;
      capture.gate = null;
      platform.permissionGate = Completer();
      final save = service.export(ExportAction.save, capture, () => current);
      await flush();
      current = false;
      platform.permissionGate?.complete(true);
      await expectLater(save, throwsA(isA<ExportFailure>()));
      expect(platform.saves, 0);
    },
  );
  test(
    'typed platform/storage failures are not converted into successful saves',
    () async {
      final platform = FakeVoucherPlatform()
        ..failure = const ExportFailure(ExportFailureKind.storageFull);
      await expectLater(
        VoucherExportService(platform)
            .export(ExportAction.save, FakeVoucherCapture(), () => true),
        throwsA(
          isA<ExportFailure>().having(
            (failure) => failure.kind,
            'kind',
            ExportFailureKind.storageFull,
          ),
        ),
      );
      expect(platform.saves, 1);
      platform.failure = const ExportFailure(ExportFailureKind.unsupported);
      await expectLater(
        VoucherExportService(platform)
            .export(ExportAction.share, FakeVoucherCapture(), () => true),
        throwsA(isA<ExportFailure>()),
      );
      expect(platform.permissions, 1);
    },
  );
  test('per-target single-flight and typed failures; revoked scope drops late completion', () async {
    final platform = FakeVoucherPlatform()..shareGate = Completer();
    final repo = FakeOffersRepository();
    final container = ProviderContainer(
      overrides: [
        offersScopeProvider.overrideWith((ref) => ref.watch(testScopeProvider)),
        offersRepositoryProvider.overrideWithValue(repo),
        voucherPlatformProvider.overrideWithValue(platform),
        clockProvider.overrideWithValue(FakeClock(DateTime(2026, 10, 8, 12))),
      ],
    );
    addTearDown(container.dispose);
    container.listen(offersControllerProvider, (_, _) {});
    container.listen(voucherExportControllerProvider, (_, _) {});
    await flush();
    final controller = container.read(voucherExportControllerProvider.notifier);
    final capture = FakeVoucherCapture();
    final first = controller.export(1, 1, ExportAction.share, capture);
    await controller.export(1, 1, ExportAction.save, capture);
    await flush();
    expect(capture.calls, 1);
    expect(platform.permissions, 0);
    expect(container.read(voucherExportControllerProvider)[1]?.busy, true);
    container.read(testScopeProvider.notifier).replace(null);
    await flush();
    platform.shareGate?.complete();
    await first;
    expect(container.read(voucherExportControllerProvider), isEmpty);
  });
}
