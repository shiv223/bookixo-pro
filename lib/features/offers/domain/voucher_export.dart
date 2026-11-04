import 'dart:typed_data';
import 'dart:ui';

import '../../../core/errors/app_failure.dart';

enum ExportAction { share, save }

abstract interface class VoucherCapture {
  Future<Uint8List> capture();
  Rect get origin;
}

abstract interface class VoucherPlatform {
  Future<bool> requestSaveAccess();
  Future<void> save(Uint8List png);
  Future<void> share(Uint8List png, Rect origin);
}

/// Rechecks ownership/eligibility after every asynchronous boundary.
class VoucherExportService {
  const VoucherExportService(this.platform);
  final VoucherPlatform platform;
  Future<void> export(
    ExportAction action,
    VoucherCapture capture,
    bool Function() eligible,
  ) async {
    void check() {
      if (!eligible()) throw const ExportFailure(ExportFailureKind.changed);
    }

    check();
    final png = await capture.capture();
    check();
    if (action == ExportAction.save) {
      final allowed = await platform.requestSaveAccess();
      check();
      if (!allowed) throw const ExportFailure(ExportFailureKind.denied);
      await platform.save(png);
    } else {
      await platform.share(png, capture.origin);
    }
  }
}
